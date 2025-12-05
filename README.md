# profile_ggonda_cassandr

## Module Description
This Puppet module, `profile_ggonda_cassandr`, is designed to configure and manage a production-ready Apache Cassandra node. It adheres to strict Puppet 3 and Puppet 6/7/8 compatibility, avoids all Forge dependencies, and uses native Puppet resources for maximum stability and control. The module focuses on production hardening, including OS-level tuning, secure configuration, and essential operational scripts for Cassandra cluster management.

## Setup & Usage

To apply this profile to a Cassandra node, declare the `profile_ggonda_cassandr` class in your node definition or Hiera.

**Example Hiera Data (YAML):**

```yaml
profile_ggonda_cassandr::cassandra_version: '4.1.10-1'
profile_ggonda_cassandr::java_version: '11'
profile_ggonda_cassandr::cluster_name: 'Production Cluster'
profile_ggonda_cassandr::seeds: '192.168.1.10,192.168.1.11'
profile_ggonda_cassandr::max_heap_size: '4G' # Example override
profile_ggonda_cassandr::datacenter: 'dc1'
profile_ggonda_cassandr::rack: 'rack1'
profile_ggonda_cassandr::gc_type: 'G1GC'
profile_ggonda_cassandr::cassandra_password: 'MyStrongPassword123!' # IMPORTANT: Manage securely, e.g., using eyaml
profile_ggonda_cassandr::disable_swap_tune_os: true
profile_ggonda_cassandr::enable_range_repair_script: false
# profile_ggonda_cassandr::replace_dead_node_ip: '192.168.1.20' # Uncomment and set if replacing a dead node
```

**Example Node Definition (manifests/site.pp or similar):**

```puppet
node 'cassandra-node-01.example.com' {
  class { 'profile_ggonda_cassandr': }
}
```

## Parameters Reference

The following parameters can be configured via Hiera for the `profile_ggonda_cassandr` class. Default values are explicitly defined within the `init.pp` manifest.

| Hiera Key                                     | Default Value         | Description                                                          |
| :-------------------------------------------- | :-------------------- | :------------------------------------------------------------------- |
| `profile_ggonda_cassandr::cassandra_version`  | `'4.1.10-1'`          | Specific Cassandra version to install.                               |
| `profile_ggonda_cassandr::java_version`       | `'11'`                | Java version to install (e.g., '8' or '11').                         |
| `profile_ggonda_cassandr::profile_tag`        | `'v2.1.0'`            | A tag for tracking this profile's version.                           |
| `profile_ggonda_cassandr::cluster_name`       | `'Production Cluster'`| Name of the Cassandra cluster.                                       |
| `profile_ggonda_cassandr::seeds`              | `'192.168.1.10,192.168.1.11'` | Comma-separated list of seed node IP addresses.                      |
| `profile_ggonda_cassandr::max_heap_size`      | `'2G'`                | Maximum JVM heap size for Cassandra (e.g., '2G', '4G').              |
| `profile_ggonda_cassandr::datacenter`         | `'dc1'`               | Datacenter name for Cassandra.                                       |
| `profile_ggonda_cassandr::rack`               | `'rack1'`             | Rack name for Cassandra.                                             |
| `profile_ggonda_cassandr::gc_type`            | `'G1GC'`              | JVM Garbage Collector type (e.g., 'G1GC', 'CMS').                    |
| `profile_ggonda_cassandr::cassandra_user`     | `'cassandra'`         | Cassandra superuser username.                                        |
| `profile_ggonda_cassandr::cassandra_password` | `'PP/C@ss@ndr@123'`   | **CRITICAL:** Cassandra superuser password. Use Hiera eyaml!       |
| `profile_ggonda_cassandr::data_directory`     | `'/var/lib/cassandra/data'` | Base directory for Cassandra data files.                             |
| `profile_ggonda_cassandr::commitlog_directory`| `'/var/lib/cassandra/commitlog'` | Directory for Cassandra commit log files.                        |
| `profile_ggonda_cassandr::disable_swap_tune_os`| `'true'`             | Boolean (as string) to enable/disable OS swap/sysctl tuning.         |
| `profile_ggonda_cassandr::replace_dead_node_ip`| `''`                 | IP address of a dead node being replaced (empty if not replacing).   |
| `profile_ggonda_cassandr::enable_range_repair_script`| `'false'`     | Boolean (as string) to enable/disable the automated range repair service. |

## Operational Guide

This module provides a set of utility scripts located in `/usr/local/bin` on each Cassandra node for common operational tasks.

*   `/usr/local/bin/check-versions.sh`: Audits and prints versions of OS, Kernel, Puppet, Java, Cassandra, and Python.
*   `/usr/local/bin/cluster-health.sh`: Checks Cassandra cluster health via `nodetool status`, `cqlsh` connection, and port 9042 listening.
*   `/usr/local/bin/repair-node.sh`: Executes `nodetool repair -pr` for primary ranges on the local node.
*   `/usr/local/bin/cleanup-node.sh`: Executes `nodetool cleanup` to remove data that no longer belongs to the node.
*   `/usr/local/bin/take-snapshot.sh -t <name> [-k <keyspace>] [-tb <table>]`: Creates a Cassandra snapshot.
*   `/usr/local/bin/drain-node.sh`: Flushes memtables and stops listening for client connections, preparing for a clean shutdown.
*   `/usr/local/bin/rebuild-node.sh [-dc <datacenter>]`: Rebuilds a node by streaming data from other nodes, useful for new or replaced nodes.
*   `/usr/local/bin/garbage-collect.sh [-k <keyspace>] [-tb <table>]`: Forces a major compaction (garbage collection) on specified keyspaces/tables.
*   `/usr/local/bin/assassinate-node.sh -ip <node_ip>`: **USE WITH EXTREME CAUTION!** Forcefully removes a dead node from the cluster. Requires confirmation.
*   `/usr/local/bin/upgrade-sstables.sh [-k <keyspace>] [-tb <table>]`: Upgrades SSTables on the node to the current format.
*   `/usr/local/bin/backup-to-s3.sh [-t <snapshot_name>] [-k <keyspace>]`: Creates a snapshot, archives it, and simulates upload to S3. This script is a mock and needs actual S3 CLI integration for production use.
*   `/usr/local/bin/prepare-replacement.sh`: Provides preliminary checks and suggestions (cleanup, drain) before a node replacement operation.
*   `/usr/local/bin/range-repair.sh {start|stop|restart|status|--help}`: Manages a daemon service that periodically runs `nodetool repair -pr`. Enabled via `enable_range_repair_script` Hiera parameter.

Each script supports a `-h` or `--help` flag for detailed usage information.

## Architecture

This module implements the "Profile" pattern in Puppet. It encapsulates all necessary configurations and resources to manage a complete Cassandra installation on a server. It is designed to be assigned directly to nodes via Hiera or node definitions, providing a clear, self-contained view of a Cassandra node's desired state. The "no forge dependencies" rule ensures minimal external reliance and simplifies auditing for critical production systems.
