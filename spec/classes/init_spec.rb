require 'spec_helper'

describe 'profile_ggonda_cassandr' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      # Mock the ipaddress fact for predictable testing
      let(:facts) do
        os_facts.merge({
          :ipaddress => '192.168.1.100',
        })
      end

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('profile_ggonda_cassandr') }

        it { is_expected.to contain_package('cassandra').with_ensure('4.1.10-1') }
        it { is_expected.to contain_package('java-11-openjdk-headless').with_ensure('present') }
        it { is_expected.to contain_file('/etc/cassandra/conf/cassandra.yaml').with_content(/cluster_name: Production Cluster/) }
        it { is_expected.to contain_file('/etc/cassandra/conf/cassandra.yaml').with_content(/seeds: "192.168.1.10,192.168.1.11"/) }
        it { is_expected.to contain_file('/etc/cassandra/conf/cassandra.yaml').with_content(/listen_address: 192.168.1.100/) }
        it { is_expected.to contain_file('/etc/cassandra/conf/jvm-server.options').with_content(/-Xmx2G/) }
        it { is_expected.to contain_file('/etc/cassandra/conf/jvm-server.options').with_content(/-XX:\+UseG1GC/) }
        it { is_expected.to contain_service('cassandra').with_ensure('running').with_enable(true) }
        it { is_expected.to contain_exec('change-cassandra-password').with_unless(/cqlsh -u cassandra -p 'PP\/C@ss@ndr@123' -e 'exit'/) }

        # Ensure swapoff and fstab modification if disable_swap_tune_os is true (default)
        it { is_expected.to contain_exec('swapoff -a') }
        it { is_expected.to contain_file_line('disable_swap_in_fstab') }

        # Check for neutralized jvm-options files
        it { is_expected.to contain_file('/etc/cassandra/conf/jvm8-server.options').with_content(/# Managed by Puppet. Neutralized/) }
        it { is_expected.to contain_file('/etc/cassandra/conf/jvm11-server.options').with_content(/# Managed by Puppet. Neutralized/) }

        # Check for jamm-0.3.2.jar
        it { is_expected.to contain_file('/usr/share/cassandra/lib/jamm-0.3.2.jar').with_owner('cassandra').with_group('cassandra').with_mode('0644') }
      end

      context 'with disable_swap_tune_os set to false' do
        let(:params) { { :disable_swap_tune_os => false } }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_exec('swapoff -a') }
        it { is_expected.not_to contain_file_line('disable_swap_in_fstab') }
      end

      context 'with enable_range_repair_script set to true' do
        let(:params) { { :enable_range_repair_script => true } }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/systemd/system/range-repair.service') }
        it { is_expected.to contain_service('range-repair').with_ensure('running').with_enable(true) }
      end

      context 'with different Cassandra version' do
        let(:params) { { :cassandra_version => '3.11.16' } }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('cassandra').with_ensure('3.11.16') }
        it { is_expected.to contain_file('/etc/cassandra/conf/cassandra.yaml').with_content(/start_rpc: true/) }
      end

      context 'with different Java version (e.g., 8)' do
        let(:params) { { :java_version => '8' } }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/cassandra/conf/jvm-server.options').with_content(/-Xloggc:\/var\/log\/cassandra\/gc.log/) }
        it { is_expected.not_to contain_file('/etc/cassandra/conf/jvm-server.options').with_content(/^-Xlog:gc/) }
      end

    end
  end
end
