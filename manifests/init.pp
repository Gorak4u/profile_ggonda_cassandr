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
  $cassandra_password          = hiera('profile_ggonda_cassandr::cassandra_password', 'PP/C@ss@ndr@123'),
  $data_dir                    = hiera('profile_ggonda_cassandr::data_dir', '/var/lib/cassandra/data'),
  $commitlog_dir               = hiera('profile_ggonda_cassandr::commitlog_dir', '/var/lib/cassandra/commitlog'),
  $disable_swap_tune_os        = hiera('profile_ggonda_cassandr::disable_swap_tune_os', true),
  $replace_dead_node_ip        = hiera('profile_ggonda_cassandr::replace_dead_node_ip', ''),
  $enable_range_repair_script  = hiera('profile_ggonda_cassandr::enable_range_repair_script', false),
) {

  # --- OS Tuning and Hardening ---
  if "${disable_swap_tune_os}" == "true" {
    exec { 'swapoff -a':
      command => 'swapoff -a',
      path    => ['/usr/bin', '/usr/sbin'],
      onlyif  => 'grep -q swap /proc/swaps',
      before  => File_line['disable_swap_in_fstab'],
    }

    file_line { 'disable_swap_in_fstab':
      path    => '/etc/fstab',
      line    => '#UUID=xxxx-xxxx none swap sw 0 0 # Managed by Puppet to disable swap',
      match   => '^\S+\s+none\s+swap\s+sw\s+0\s+0$',
      replace => true,
    }

    sysctl { 'vm.max_map_count':
      value   => '1048575',
      comment => 'Cassandra requirement',
    }

    sysctl { 'fs.aio-max-nr':
      value   => '1048576',
      comment => 'Cassandra requirement',
    }

    file { '/etc/security/limits.d/cassandra.conf':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => """
cassandra - memlock unlimited
cassandra - nofile 1048575
cassandra - nproc 65535
""",
    }
  }

  # --- YUM Repository for Cassandra ---
  # EL7, EL8, EL9 support logic
  $cassandra_repo_baseurl = $::operatingsystemmajrelease ? {
    '7'     => 'https://downloads.apache.org/cassandra/${cassandra_version_major}/redhat/7/',
    '8'     => 'https://downloads.apache.org/cassandra/${cassandra_version_major}/redhat/8/',
    '9'     => 'https://downloads.apache.org/cassandra/${cassandra_version_major}/redhat/9/',
    default => "https://downloads.apache.org/cassandra/${cassandra_version_major}/redhat/${::operatingsystemmajrelease}/", # Fallback
  }

  $cassandra_version_major = split($cassandra_version, '\.')[0]

  yumrepo { 'cassandra':
    descr    => "Apache Cassandra ${cassandra_version_major}.x Repository",
    baseurl  => "https://downloads.apache.org/cassandra/${cassandra_version_major}/redhat/${::operatingsystemmajrelease}/",
    enabled  => 1,
    gpgcheck => 1,
    gpgkey   => 'https://downloads.apache.org/cassandra/KEYS',
  }

  # --- Packages ---
  # Java
  package { 'java-11-openjdk-headless':
    ensure  => 'present',
  }

  # Cassandra
  package { 'cassandra':
    ensure  => $cassandra_version,
    require => Yumrepo['cassandra'],
  }

  # Python for cqlsh
  package { ['python3', 'python3-pip']:
    ensure  => 'present',
  }

  # jemalloc for performance
  package { 'jemalloc':
    ensure  => 'present',
  }

  # --- Users and Directories ---
  user { 'cassandra':
    ensure     => 'present',
    comment    => 'Cassandra Database User',
    home       => '/var/lib/cassandra',
    shell      => '/sbin/nologin',
    managehome => false,
    require    => Package['cassandra'], # Ensure package creates system user first
  }

  group { 'cassandra':
    ensure  => 'present',
    require => Package['cassandra'],
  }

  file { '/etc/cassandra/conf':
    ensure  => directory,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0755',
    require => Package['cassandra'],
  }

  file { $data_dir:
    ensure  => directory,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0755',
    require => User['cassandra'],
  }

  file { $commitlog_dir:
    ensure  => directory,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0755',
    require => User['cassandra'],
  }

  # --- Configuration Files ---
  file { '/etc/cassandra/conf/cassandra.yaml':
    ensure  => file,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0644',
    content => template('profile_ggonda_cassandr/cassandra.yaml.erb'),
    require => File['/etc/cassandra/conf'],
    notify  => Service['cassandra'],
  }

  file { '/etc/cassandra/conf/cassandra-rackdc.properties':
    ensure  => file,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0644',
    content => template('profile_ggonda_cassandr/cassandra-rackdc.properties.erb'),
    require => File['/etc/cassandra/conf'],
    notify  => Service['cassandra'],
  }

  # This template now manages the active JVM options, and is renamed to jvm-server.options
  file { '/etc/cassandra/conf/jvm-server.options':
    ensure  => file,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0644',
    content => template('profile_ggonda_cassandr/jvm-server.options.erb'),
    require => File['/etc/cassandra/conf'],
    notify  => Service['cassandra'],
  }

  # Neutralize jvm8-server.options and jvm11-server.options to prevent conflicts
  # as jvm-server.options is now dynamically sourced based on Java version.
  file { '/etc/cassandra/conf/jvm8-server.options':
    ensure  => file,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0644',
    content => '# Managed by Puppet. Neutralized to prevent conflicting JVM options. Use jvm-server.options instead.',
    require => File['/etc/cassandra/conf'],
    notify  => Service['cassandra'],
  }

  file { '/etc/cassandra/conf/jvm11-server.options':
    ensure  => file,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0644',
    content => '# Managed by Puppet. Neutralized to prevent conflicting JVM options. Use jvm-server.options instead.',
    require => File['/etc/cassandra/conf'],
    notify  => Service['cassandra'],
  }

  # Cassandra environment variables, usually managed by the package
  # This ensures it exists and is not overwritten by Puppet unless strictly necessary.
  file { '/etc/cassandra/conf/cassandra-env.sh':
    ensure  => file,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0755',
    require => File['/etc/cassandra/conf'],
  }

  file { '/root/.cassandra':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  file { '/root/.cassandra/cqlshrc':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('profile_ggonda_cassandr/cqlshrc.erb'),
    require => File['/root/.cassandra'],
  }

  # Manage jamm-0.3.2.jar
  file { '/usr/share/cassandra/lib/jamm-0.3.2.jar':
    ensure  => file,
    owner   => 'cassandra',
    group   => 'cassandra',
    mode    => '0644',
    source  => 'puppet:///modules/profile_ggonda_cassandr/jamm-0.3.2.jar',
    require => Package['cassandra'],
    notify  => Service['cassandra'],
  }

  # --- Cassandra Service ---
  service { 'cassandra':
    ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => [
      Package['cassandra'],
      File['/etc/cassandra/conf/cassandra.yaml'],
      File['/etc/cassandra/conf/cassandra-rackdc.properties'],
      File['/etc/cassandra/conf/jvm-server.options'],
      File['/usr/share/cassandra/lib/jamm-0.3.2.jar'],
    ],
  }

  # --- Scripts for /usr/local/bin ---
  # Ensure /usr/local/bin exists
  file { '/usr/local/bin':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

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
    'range-repair.sh',
  ]

  file { $scripts:
    ensure  => file,
    path    => "/usr/local/bin/${name}",
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => "puppet:///modules/profile_ggonda_cassandr/${name}",
    require => File['/usr/local/bin'],
  }

  # --- Range Repair Systemd Service ---
  if "${enable_range_repair_script}" == "true" {
    file { '/etc/systemd/system/range-repair.service':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('profile_ggonda_cassandr/range-repair.service.erb'),
      require => File['/usr/local/bin/range-repair.sh'],
      notify  => Exec['systemctl-daemon-reload-range-repair'],
    }

    exec { 'systemctl-daemon-reload-range-repair':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      subscribe   => File['/etc/systemd/system/range-repair.service'],
    }

    service { 'range-repair':
      ensure    => 'running',
      enable    => true,
      subscribe => File['/etc/systemd/system/range-repair.service'],
      require   => Exec['systemctl-daemon-reload-range-repair'],
    }
  }

  # --- Cassandra Password Change ---
  exec { 'change-cassandra-password':
    command     => "cqlsh -u cassandra -p cassandra -e \"ALTER USER cassandra WITH PASSWORD '${cassandra_password}';\"",
    path        => ['/usr/bin', '/usr/local/bin'],
    user        => 'root',
    logoutput   => true,
    tries       => 10,
    try_sleep   => 10,
    unless      => "cqlsh -u cassandra -p '${cassandra_password}' -e 'exit'",
    require     => Service['cassandra'],
    timeout     => 60, # Allow sufficient time for cqlsh to connect and run
  }
}
