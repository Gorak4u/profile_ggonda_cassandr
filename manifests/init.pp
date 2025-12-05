class profile_ggonda_cassandr (
  $cassandra_version           = hiera('profile_ggonda_cassandr::cassandra_version', '4.1.10-1'),
  $java_version                = hiera('profile_ggonda_cassandr::java_version', '11'),
  $profile_tag                 = hiera('profile_ggonda_cassandr::profile_tag', 'v2.1.0'),
  $cluster_name                = hiera('profile_ggonda_cassandr::cluster_name', 'Production Cluster'),
  $seeds                       = hiera('profile_ggonda_cassandr::seeds', '192.168.1.10,192.168.1.11'),
  $max_heap_size               = hiera('profile_ggonda_cassandr::max_heap_size', '2G'),
  $datacenter                  = hiera('profile_ggonda_cassandr::datacenter', 'dc1'),
  $rack                        = hiera('profile_ggonda_cassandr::rack', 'rack1'),
  $gc_type                     = hiera('profile_ggonda_cassandr::gc_type', 'G1GC'),
  $cassandra_user              = hiera('profile_ggonda_cassandr::cassandra_user', 'cassandra'),
  $cassandra_password          = hiera('profile_ggonda_cassandr::cassandra_password', 'PP/C@ss@ndr@123'),
  $data_directory              = hiera('profile_ggonda_cassandr::data_directory', '/var/lib/cassandra/data'),
  $commitlog_directory         = hiera('profile_ggonda_cassandr::commitlog_directory', '/var/lib/cassandra/commitlog'),
  $disable_swap_tune_os        = hiera('profile_ggonda_cassandr::disable_swap_tune_os', 'true'),
  $replace_dead_node_ip        = hiera('profile_ggonda_cassandr::replace_dead_node_ip', ''),
  $enable_range_repair_script  = hiera('profile_ggonda_cassandr::enable_range_repair_script', 'false')
) {

  # Ensure common tools are present
  package { [
    'curl',
    'wget',
    'vim',
    'git',
    'net-tools',
    'iproute',
    'rsync'
  ]:
    ensure => installed,
  }

  # OS Tuning
  if "$disable_swap_tune_os" == "true" {
    # Disable Swap
    file { '/etc/fstab':
      ensure  => file,
      content => regsubst(file('/etc/fstab'), '^([^#].*\s+swap\s+.*)$', '#\1', 'G'),
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
    }

    # Sysctl tuning for Cassandra
    file { '/etc/sysctl.d/99-cassandra.conf':
      ensure  => file,
      content => "
# Tuned for Cassandra\n
vm.max_map_count = 1048575\n
net.ipv4.tcp_keepalive_time = 600\n
net.ipv4.tcp_keepalive_probes = 3\n
net.ipv4.tcp_keepalive_intvl = 60\n
net.core.somaxconn = 32768\n
net.core.netdev_max_backlog = 10000\n
net.ipv4.tcp_rmem = 4096 87380 16777216\n
net.ipv4.tcp_wmem = 4096 87380 16777216\n",
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      notify  => Exec['apply-sysctl-cassandra'],
    }

    exec { 'apply-sysctl-cassandra':
      command     => '/sbin/sysctl -p /etc/sysctl.d/99-cassandra.conf',
      refreshonly => true,
      tries       => 10,
      try_sleep   => 10,
    }

    # Limits for Cassandra user
    file { '/etc/security/limits.d/cassandra.conf':
      ensure  => file,
      content => "
cassandra - memlock unlimited\n
cassandra - nofile 100000\n
cassandra - nproc 32768\n
cassandra - as unlimited\n",
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
    }
  }

  # YUM Repository for Cassandra
  if ($::osfamily == 'RedHat') {
    $release = $::operatingsystemmajrelease
    if ($release == '7') {
      $yum_baseurl = "https://downloads.apache.org/cassandra/${cassandra_version}/redhat/${release}"
      $yum_gpgkey = "https://downloads.apache.org/cassandra/KEYS"
    } elsif ($release == '8') {
      $yum_baseurl = "https://downloads.apache.org/cassandra/${cassandra_version}/redhat/${release}"
      $yum_gpgkey = "https://downloads.apache.org/cassandra/KEYS"
    } elsif ($release == '9') {
      $yum_baseurl = "https://downloads.apache.org/cassandra/${cassandra_version}/redhat/${release}"
      $yum_gpgkey = "https://downloads.apache.org/cassandra/KEYS"
    } else {
      fail("Unsupported RedHat-based OS release for Cassandra repository: ${release}")
    }

    yumrepo { 'apache-cassandra':
      descr    => 'Apache Cassandra Repository',
      baseurl  => $yum_baseurl,
      gpgcheck => 1,
      gpgkey   => $yum_gpgkey,
      enabled  => 1,
      require  => Package['curl'],
    }
  } else {
    fail("Unsupported OS family for Cassandra repository: ${::osfamily}")
  }

  # Install Java
  if "$java_version" == "11" {
    package { 'java-11-openjdk-devel':
      ensure => installed,
    }
    exec { 'set-java-home':
      command => "/usr/sbin/alternatives --set java /usr/lib/jvm/java-11-openjdk/bin/java && \
                  /usr/sbin/alternatives --set javac /usr/lib/jvm/java-11-openjdk/bin/javac",
      unless  => "/usr/bin/java -version 2>&1 | grep 'openjdk version \"11.'",
      path    => '/usr/bin:/usr/sbin:/bin',
      require => Package['java-11-openjdk-devel'],
    }
  } elsif "$java_version" == "8" {
    package { 'java-1.8.0-openjdk-devel':
      ensure => installed,
    }
    exec { 'set-java-home':
      command => "/usr/sbin/alternatives --set java /usr/lib/jvm/java-1.8.0-openjdk/jre/bin/java && \
                  /usr/sbin/alternatives --set javac /usr/lib/jvm/java-1.8.0-openjdk/bin/javac",
      unless  => "/usr/bin/java -version 2>&1 | grep 'openjdk version \"1.8.'",
      path    => '/usr/bin:/usr/sbin:/bin',
      require => Package['java-1.8.0-openjdk-devel'],
    }
  } else {
    fail("Unsupported Java version: ${java_version}")
  }

  # Install other required packages
  package { [
    'python3',
    'jemalloc'
  ]:
    ensure  => installed,
    require => Yumrepo['apache-cassandra'],
  }

  # Install Cassandra
  package { 'cassandra':
    ensure  => $cassandra_version,
    require => [
      Yumrepo['apache-cassandra'],
      # Conditional Java package require
      ("$java_version" == "11" ? Package['java-11-openjdk-devel'] : Package['java-1.8.0-openjdk-devel']),
      Package['python3'],
      Package['jemalloc'],
    ],
  }

  # Cassandra user and groups
  user { $cassandra_user:
    ensure     => present,
    shell      => '/sbin/nologin',
    home       => '/var/lib/cassandra',
    managehome => false,
  }

  group { $cassandra_user:
    ensure => present,
  }

  # Data and Commitlog Directories
  file { [$data_directory, $commitlog_directory]:
    ensure  => directory,
    owner   => $cassandra_user,
    group   => $cassandra_user,
    mode    => '0755',
    require => [User[$cassandra_user], Group[$cassandra_user]],
  }

  # Cassandra config directory
  file { '/etc/cassandra/conf':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    recurse => true,
  }

  # Manage Cassandra config files from templates
  file { '/etc/cassandra/conf/cassandra.yaml':
    ensure  => file,
    content => template('profile_ggonda_cassandr/cassandra.yaml.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['cassandra'],
    notify  => Service['cassandra'],
  }

  file { '/etc/cassandra/conf/jvm-server.options':
    ensure  => file,
    content => template('profile_ggonda_cassandr/jvm-server.options.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['cassandra'],
    notify  => Service['cassandra'],
  }

  file { '/etc/cassandra/conf/cassandra-rackdc.properties':
    ensure  => file,
    content => template('profile_ggonda_cassandr/cassandra-rackdc.properties.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['cassandra'],
    notify  => Service['cassandra'],
  }

  # Neutralize jvm8-server.options and jvm11-server.options
  file { ['/etc/cassandra/conf/jvm8-server.options', '/etc/cassandra/conf/jvm11-server.options']:
    ensure  => file,
    content => '# Managed by Puppet. This file is intentionally empty or commented to prevent conflicting GC settings.\n',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['cassandra'],
    notify  => Service['cassandra'],
  }

  # Manage jamm-0.3.2.jar
  file { '/usr/share/cassandra/lib/jamm-0.3.2.jar':
    ensure  => file,
    source  => 'puppet:///modules/profile_ggonda_cassandr/jamm-0.3.2.jar',
    owner   => $cassandra_user,
    group   => $cassandra_user,
    mode    => '0644',
    require => [Package['cassandra'], User[$cassandra_user], Group[$cassandra_user]],
    notify  => Service['cassandra'],
  }

  # Manage /root/.cassandra/cqlshrc
  file { '/root/.cassandra':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }
  file { '/root/.cassandra/cqlshrc':
    ensure  => file,
    content => template('profile_ggonda_cassandr/cqlshrc.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => File['/root/.cassandra'],
  }

  # Deploy scripts to /usr/local/bin
  $scripts = [
    'check-versions.sh',
    'cluster-health.sh',
    'repair-node.sh',
    'cleanup-node.sh',
    'take-snapshot.sh',
    'drain-node.sh',
    'rebuild-node.sh',
    'garbage-collect.sh',
    'assassinate-node.sh',
    'upgrade-sstables.sh',
    'backup-to-s3.sh',
    'prepare-replacement.sh',
    'range-repair.sh'
  ]

  file { $scripts:
    ensure  => file,
    path    => "/usr/local/bin/${title}",
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => "puppet:///modules/profile_ggonda_cassandr/${title}",
    require => Package['cassandra'],
  }

  # Range Repair Service (Systemd)
  if "$enable_range_repair_script" == "true" {
    file { '/etc/systemd/system/range-repair.service':
      ensure  => file,
      content => template('profile_ggonda_cassandr/range-repair.service.erb'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => File['/usr/local/bin/range-repair.sh'],
      notify  => Exec['daemon-reload-range-repair'],
    }

    exec { 'daemon-reload-range-repair':
      command     => '/bin/systemctl daemon-reload',
      refreshonly => true,
      require     => File['/etc/systemd/system/range-repair.service'],
    }

    service { 'range-repair':
      ensure    => running,
      enable    => true,
      subscribe => File['/etc/systemd/system/range-repair.service'],
      require   => Exec['daemon-reload-range-repair'],
    }
  }

  # Cassandra Service
  service { 'cassandra':
    ensure    => running,
    enable    => true,
    subscribe => [
      Package['cassandra'],
      File['/etc/cassandra/conf/cassandra.yaml'],
      File['/etc/cassandra/conf/jvm-server.options'],
      File['/etc/cassandra/conf/cassandra-rackdc.properties'],
      File['/usr/share/cassandra/lib/jamm-0.3.2.jar'],
    ],
    require   => [
      Package['cassandra'],
      File['/etc/cassandra/conf/cassandra.yaml'],
      File['/etc/cassandra/conf/jvm-server.options'],
      File['/etc/cassandra/conf/cassandra-rackdc.properties'],
      File['/usr/share/cassandra/lib/jamm-0.3.2.jar'],
    ],
  }

  # Password change for Cassandra user (idempotent)
  exec { 'change-cassandra-password':
    command     => "cqlsh -u ${cassandra_user} -p ${cassandra_user} -e \"ALTER USER ${cassandra_user} WITH PASSWORD '${cassandra_password}';\"",
    unless      => "cqlsh -u ${cassandra_user} -p '${cassandra_password}' -e 'exit'",
    path        => ['/usr/bin', '/usr/sbin', '/bin'],
    user        => 'root',
    require     => Service['cassandra'],
    refreshonly => false,
    tries       => 10,
    try_sleep   => 10,
  }
}