# @summary Computes the resource title prefix for a given PostgreSQL server instance.
#
# The 'main' instance is never prefixed, keeping its resource titles identical
# to the single-instance behavior. For other instances, the prefix is driven by
# the `$instance_title_prefix` parameter of the `postgresql::globals` class:
# * `true` (default) - the automatic prefix `"<instance> "`.
# * `false` - no prefix at all.
# * A hash of instance name to prefix - the given prefix for listed instances,
#   the automatic prefix for the others.
#
# @example
#   postgresql::instance_title_prefix('main')  # ''
#   postgresql::instance_title_prefix('inst1') # 'inst1 ' (default)
#
# @param instance
#   The name of the server instance.
#
# @return [String]
#   The prefix to prepend to the resource titles of the instance.
#
function postgresql::instance_title_prefix(String[1] $instance) >> String {
  if $instance == 'main' {
    return ''
  }

  include postgresql::params

  $config = getvar('postgresql::params::instance_title_prefix')
  if $config == false {
    return ''
  }

  if $config =~ Hash {
    return(pick_default($config[$instance], "${instance} "))
  }

  "${instance} "
}
