# frozen_string_literal: true

require 'spec_helper'

describe 'postgresql::instance_title_prefix' do
  let(:facts) do
    {
      'os' => {
        'family' => 'Debian',
        'name'   => 'Debian',
        'release' => {
          'full'  => '11.7',
          'major' => '11',
          'minor' => '7',
        }
      }
    }
  end

  context 'with default configuration (true)' do
    it { is_expected.to run.with_params('main').and_return('') }
    it { is_expected.to run.with_params('inst1').and_return('inst1 ') }
  end

  context 'with instance_title_prefix set to false' do
    let(:pre_condition) do
      <<~PUPPET
      class { 'postgresql::globals':
        instance_title_prefix => false,
      }
      PUPPET
    end

    it { is_expected.to run.with_params('main').and_return('') }
    it { is_expected.to run.with_params('inst1').and_return('') }
  end

  context 'with instance_title_prefix set to a hash' do
    let(:pre_condition) do
      <<~PUPPET
      class { 'postgresql::globals':
        instance_title_prefix => {
          'inst1' => 'i1_',
          'inst2' => '',
        },
      }
      PUPPET
    end

    it { is_expected.to run.with_params('main').and_return('') }
    it { is_expected.to run.with_params('inst1').and_return('i1_') }
    it { is_expected.to run.with_params('inst2').and_return('') }
    it { is_expected.to run.with_params('inst3').and_return('inst3 ') }
  end
end
