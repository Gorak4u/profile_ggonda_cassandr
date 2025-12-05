require 'spec_helper'

describe 'profile_ggonda_cassandr' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      # Define default Hiera data for testing
      let(:hiera_data) do
        {
          'profile_ggonda_cassandr::cassandra_version'          => '4.1.10-1',
          'profile_ggonda_cassandr::java_version'               => '11',
          'profile_ggonda_cassandr::cluster_name'               => 'Test Cluster',
          'profile_ggonda_cassandr::seeds'                      => '10.0.0.1,10.0.0.2',
          'profile_ggonda_cassandr::max_heap_size'              => '2G',
          'profile_ggonda_cassandr::datacenter'                 => 'testdc',
          'profile_ggonda_cassandr::rack'                       => 'testrack',
          'profile_ggonda_cassandr::gc_type'                    => 'G1GC',
          'profile_ggonda_cassandr::cassandra_user'             => 'cassandra',
          'profile_ggonda_cassandr::cassandra_password'         => 'TestPassword123!',
          'profile_ggonda_cassandr::data_directory'             => '/var/lib/cassandra/data',
          'profile_ggonda_cassandr::commitlog_directory'        => '/var/lib/cassandra/commitlog',
          'profile_ggonda_cassandr::disable_swap_tune_os'       => 'true',
          'profile_ggonda_cassandr::replace_dead_node_ip'       => '',
          'profile_ggonda_cassandr::enable_range_repair_script' => 'false'
        }
      end

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('profile_ggonda_cassandr') }

      # Basic checks for core resources
      it { is_expected.to contain_package('cassandra').with_ensure('4.1.10-1') }
      it { is_expected.to contain_service('cassandra').with_ensure('running').with_enable(true) }
      it { is_expected.to contain_file('/etc/cassandra/conf/cassandra.yaml').with_content(/cluster_name: 'Test Cluster'/) }
      it { is_expected.to contain_file('/etc/cassandra/conf/jvm-server.options').with_content(/-Xmx2G/) }
      it { is_expected.to contain_file('/etc/cassandra/conf/cassandra-rackdc.properties').with_content(/dc=testdc/) }

      it { is_expected.to contain_user('cassandra').with_ensure('present') }
      it { is_expected.to contain_group('cassandra').with_ensure('present') }
      it { is_expected.to contain_file('/var/lib/cassandra/data').with_ensure('directory') }
      it { is_expected.to contain_file('/usr/share/cassandra/lib/jamm-0.3.2.jar').with_source('puppet:///modules/profile_ggonda_cassandr/jamm-0.3.2.jar') }

      # OS Tuning checks
      if os_facts[:operatingsystemmajrelease].to_i >= 7
        it { is_expected.to contain_file('/etc/fstab').with_content(/#\s+swap/) }
        it { is_expected.to contain_file('/etc/sysctl.d/99-cassandra.conf').with_content(/vm.max_map_count/) }
        it { is_expected.to contain_exec('apply-sysctl-cassandra').with_refreshonly(true) }
        it { is_expected.to contain_file('/etc/security/limits.d/cassandra.conf').with_content(/cassandra - nofile 100000/) }
      end

      # Yum repo check
      it { is_expected.to contain_yumrepo('apache-cassandra').with_baseurl(%r{https://downloads.apache.org/cassandra/4.1.10-1/redhat/}) }
      it { is_expected.to contain_yumrepo('apache-cassandra').with_gpgcheck(1) }
      it { is_expected.to contain_yumrepo('apache-cassandra').with_gpgkey(%r{https://downloads.apache.org/cassandra/KEYS}) }

      # Java package check
      if os_facts[:osfamily] == 'RedHat' && os_facts[:operatingsystemmajrelease].to_i >= 7
        it { is_expected.to contain_package('java-11-openjdk-devel').with_ensure('installed') }
      end

      # Script deployment check (just one example)
      it { is_expected.to contain_file('/usr/local/bin/check-versions.sh').with_mode('0755') }

      # Password change exec (idempotency check)
      it { is_expected.to contain_exec('change-cassandra-password').with_unless("cqlsh -u cassandra -p 'TestPassword123!' -e 'exit'") }
      it { is_expected.to contain_exec('change-cassandra-password').with_command("cqlsh -u cassandra -p cassandra -e \"ALTER USER cassandra WITH PASSWORD 'TestPassword123!';\"") }

      context 'with range repair script enabled' do
        let(:hiera_data) do
          super().merge('profile_ggonda_cassandr::enable_range_repair_script' => 'true')
        end
        it { is_expected.to contain_file('/etc/systemd/system/range-repair.service').with_content(/Description=Cassandra Range Repair Service/) }
        it { is_expected.to contain_service('range-repair').with_ensure('running').with_enable(true) }
      end

      context 'with replace_dead_node_ip set' do
        let(:hiera_data) do
          super().merge('profile_ggonda_cassandr::replace_dead_node_ip' => '10.0.0.3')
        end
        it { is_expected.to contain_file('/etc/cassandra/conf/jvm-server.options').with_content(/-Dcassandra.replace_address=10.0.0.3/) }
      end

      context 'with java version 8' do
        let(:hiera_data) do
          super().merge('profile_ggonda_cassandr::java_version' => '8')
        end
        it { is_expected.to contain_package('java-1.8.0-openjdk-devel').with_ensure('installed') }
        it { is_expected.to contain_file('/etc/cassandra/conf/jvm-server.options').with_content(/-Xloggc:\/var\/log\/cassandra\/gc.log/) }
        it { is_expected.to_not contain_file('/etc/cassandra/conf/jvm-server.options').with_content(/-Xlog:gc/) }
      end
    end
  end
}