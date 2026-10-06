# @summary define to install and manage additional postgresql instances
# @param instance_name The name of the instance.
# @param instance_user The user to run the instance as.
# @param instance_group The group to run the instance as.
# @param instance_user_homedirectory The home directory of the instance user.
# @param manage_instance_user_and_group Should Puppet manage the instance user and it's primary group?.
# @param instance_directories directories needed for the instance. Option to manage the directory properties for each directory.
# @param initdb_settings Specifies a hash witn parameters for postgresql::server::instance::initdb
# @param config_settings Specifies a hash with parameters for postgresql::server::instance::config
# @param service_settings Specifies a hash with parameters for postgresql::server:::instance::service
# @param passwd_settings Specifies a hash with parameters for postgresql::server::instance::passwd
# @param roles Specifies a hash from which to generate postgresql::server::role resources.
# @param config_entries Specifies a hash from which to generate postgresql::server::config_entry resources.
# @param pg_hba_rules Specifies a hash from which to generate postgresql::server::pg_hba_rule resources.
# @param databases Specifies a hash from which to generate postgresql::server::database resources.
# @param databases_and_users Specifies a hash from which to generate postgresql::server::db resources.
# @param database_grants Specifies a hash from which to generate postgresql::server::database_grant resources.
# @param table_grants Specifies a hash from which to generate postgresql::server::table_grant resources.
# @param schemas Specifies a hash from which to generate postgresql::server::schema resources.
# @param extensions Specifies a hash from which to generate postgresql::server::extension resources.
# @param tablespaces Specifies a hash from which to generate postgresql::server::tablespace resources.
# @param privileges Specifies a hash from which to generate postgresql::server::grant resources.
# @param default_privileges Specifies a hash from which to generate postgresql::server::default_privileges resources.
# @param grant_roles Specifies a hash from which to generate postgresql::server::grant_role resources.
# @param reassign_owned_by Specifies a hash from which to generate postgresql::server::reassign_owned_by resources.
define postgresql::server_instance (
  String[1] $instance_name                          = $name,
  Boolean $manage_instance_user_and_group           = true,
  Hash $instance_directories                        = {},
  String[1] $instance_user                          = $instance_name,
  String[1] $instance_group                         = $instance_name,
  Stdlib::Absolutepath $instance_user_homedirectory = "/opt/pgsql/data/home/${instance_user}",
  Hash $initdb_settings                             = {},
  Hash $config_settings                             = {},
  Hash $service_settings                            = {},
  Hash $passwd_settings                             = {},
  Hash $roles                                       = {},
  Hash $config_entries                              = {},
  Hash $pg_hba_rules                                = {},
  Hash $databases_and_users                         = {},
  Hash $databases                                   = {},
  Hash $database_grants                             = {},
  Hash $table_grants                                = {},
  Hash $schemas                                     = {},
  Hash $extensions                                  = {},
  Hash $tablespaces                                 = {},
  Hash $privileges                                  = {},
  Hash $default_privileges                          = {},
  Hash $grant_roles                                 = {},
  Hash $reassign_owned_by                           = {},
) {
  unless($facts['os']['family'] == 'RedHat' and $facts['os']['release']['major'] == '8') {
    warning('This define postgresql::server_instance is only tested on RHEL8')
  }
  $instance_directories.each |Stdlib::Absolutepath $directory, Hash $directory_settings| {
    file { $directory:
      * => $directory_settings,
    }
  }

  if $manage_instance_user_and_group {
    user { $instance_user:
      managehome => true,
      system     => true,
      home       => $instance_user_homedirectory,
      gid        => $instance_group,
    }
    group { $instance_group:
      system => true,
    }
  }
  postgresql::server::instance::initdb { $instance_name:
    * => $initdb_settings,
  }
  postgresql::server::instance::config { $instance_name:
    * => $config_settings,
  }
  postgresql::server::instance::service { $instance_name:
    *    => $service_settings,
    port => $config_settings['port'],
    user => $instance_user,
  }
  postgresql::server::instance::reload { $instance_name:
    service_status => $service_settings['service_status'],
    service_reload => "systemctl reload ${service_settings['service_name']}.service",
  }
  postgresql::server::instance::passwd { $instance_name:
    * => $passwd_settings,
  }

  $roles.each |$rolename, $role| {
    $role_title   = "${postgresql::instance_title_prefix($name)}${rolename}"
    $role_details = $role + { 'username' => pick($role['username'], $rolename) }
    postgresql::server::role { $role_title:
      *          => $role_details,
      psql_user  => $instance_user,
      psql_group => $instance_group,
      port       => $config_settings['port'],
      instance   => $instance_name,
    }
  }

  $config_entries.each |$entry, $settings| {
    $value   = $settings['value']
    $comment = $settings['comment']
    postgresql::server::config_entry { "${entry}_${$instance_name}":
      ensure        => bool2str($value =~ Undef, 'absent', 'present'),
      key           => $entry,
      value         => $value,
      comment       => $comment,
      path          => $config_settings['postgresql_conf_path'],
      instance_name => $instance_name,
    }
  }
  $pg_hba_rules.each |String[1] $rule_name, Postgresql::Pg_hba_rule $rule| {
    $rule_title = "${rule_name} for instance ${name}"
    postgresql::server::pg_hba_rule { $rule_title:
      *      => $rule,
      target => $config_settings['pg_hba_conf_path'], # TODO: breaks if removed
    }
  }
  $databases_and_users.each |$database, $database_details| {
    $db_title   = "${postgresql::instance_title_prefix($name)}${database}"
    $db_details = $database_details + { 'dbname' => pick($database_details['dbname'], $database) }
    postgresql::server::db { $db_title:
      *          => $db_details,
      psql_user  => $instance_user,
      psql_group => $instance_group,
      port       => $config_settings['port'],
      instance   => $instance_name,
    }
  }
  $databases.each |$database, $database_details| {
    $database_title        = "${postgresql::instance_title_prefix($name)}${database}"
    $database_full_details = $database_details + { 'dbname' => pick($database_details['dbname'], $database) }
    postgresql::server::database { $database_title:
      *        => $database_full_details,
      user     => $instance_user,
      group    => $instance_group,
      port     => $config_settings['port'],
      instance => $instance_name,
    }
  }
  $database_grants.each |$db_grant_title, $dbgrants| {
    $database_grant_title = "${postgresql::instance_title_prefix($name)}${db_grant_title}"
    postgresql::server::database_grant { $database_grant_title:
      *          => $dbgrants,
      psql_user  => $instance_user,
      psql_group => $instance_group,
      port       => $config_settings['port'],
      instance   => $instance_name,
    }
  }
  $table_grants.each |$table_grant_title, $tgrants| {
    $table_grant_define_title = "${postgresql::instance_title_prefix($name)}${table_grant_title}"
    postgresql::server::table_grant { $table_grant_define_title:
      *         => $tgrants,
      psql_user => $instance_user,
      port      => $config_settings['port'],
      instance  => $instance_name,
    }
  }
  $schemas.each |$schema_key, $schema_details| {
    $schema_title        = "${postgresql::instance_title_prefix($name)}${schema_key}"
    $schema_full_details = $schema_details + { 'schema' => pick($schema_details['schema'], $schema_key) }
    postgresql::server::schema { $schema_title:
      *        => $schema_full_details,
      user     => $instance_user,
      group    => $instance_group,
      port     => $config_settings['port'],
      instance => $instance_name,
    }
  }
  $extensions.each |$extension_key, $extension_details| {
    $extension_title        = "${postgresql::instance_title_prefix($name)}${extension_key}"
    $extension_full_details = $extension_details + { 'extension' => pick($extension_details['extension'], $extension_key) }
    postgresql::server::extension { $extension_title:
      *        => $extension_full_details,
      user     => $instance_user,
      group    => $instance_group,
      port     => $config_settings['port'],
      instance => $instance_name,
    }
  }
  $tablespaces.each |$tablespace_key, $tablespace_details| {
    $tablespace_title        = "${postgresql::instance_title_prefix($name)}${tablespace_key}"
    $tablespace_full_details = $tablespace_details + { 'spcname' => pick($tablespace_details['spcname'], $tablespace_key) }
    postgresql::server::tablespace { $tablespace_title:
      *        => $tablespace_full_details,
      user     => $instance_user,
      group    => $instance_group,
      port     => $config_settings['port'],
      instance => $instance_name,
    }
  }
  $privileges.each |$grant_key, $grant_details| {
    $grant_title = "${postgresql::instance_title_prefix($name)}${grant_key}"
    postgresql::server::grant { $grant_title:
      *         => $grant_details,
      psql_user => $instance_user,
      group     => $instance_group,
      port      => $config_settings['port'],
      instance  => $instance_name,
    }
  }
  $default_privileges.each |$default_privileges_key, $default_privileges_details| {
    $default_privileges_title = "${postgresql::instance_title_prefix($name)}${default_privileges_key}"
    postgresql::server::default_privileges { $default_privileges_title:
      *         => $default_privileges_details,
      psql_user => $instance_user,
      group     => $instance_group,
      port      => $config_settings['port'],
      instance  => $instance_name,
    }
  }
  $grant_roles.each |$grant_role_key, $grant_role_details| {
    $grant_role_title        = "${postgresql::instance_title_prefix($name)}${grant_role_key}"
    $grant_role_full_details = $grant_role_details + { 'role' => pick($grant_role_details['role'], $grant_role_key) }
    postgresql::server::grant_role { $grant_role_title:
      *         => $grant_role_full_details,
      psql_user => $instance_user,
      port      => $config_settings['port'],
      instance  => $instance_name,
    }
  }
  $reassign_owned_by.each |$reassign_key, $reassign_details| {
    $reassign_title = "${postgresql::instance_title_prefix($name)}${reassign_key}"
    postgresql::server::reassign_owned_by { $reassign_title:
      *         => $reassign_details,
      psql_user => $instance_user,
      group     => $instance_group,
      port      => $config_settings['port'],
      instance  => $instance_name,
    }
  }
}
