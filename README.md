# profile_ggonda_cassandr

## Module Description

This Puppet profile module, `profile_ggonda_cassandr`, is designed to deploy, configure, and manage Apache Cassandra instances on RHEL-based systems (CentOS, RedHat). It enforces best practices for Cassandra configuration, OS tuning, and security, ensuring high availability and performance.

Key features include:
*   **Version Pinning**: Strict control over Cassandra and Java versions.
*   **OS Tuning**: Manages swap, sysctl parameters, and user limits for optimal Cassandra operation.
*   **Configuration Management**: Comprehensive management of `cassandra.yaml`, `jvm-server.options`, `cassandra-rackdc.properties`, and cqlsh client configuration.
*   **Security Hardening**: Enforces GPG checks for YUM repositories and automates password changes for the `cassandra` user.
*   **Monitoring & Operations Scripts**: Provides a suite of utility scripts for health checks, repairs, snapshots, and other operational tasks.
*   **Puppet 3 & 6/7/8 Compatibility**: Built with an emphasis on broad Puppet version compatibility without forge dependencies.

## Setup & Usage

To use this module, declare the `profile_ggonda_cassandr` class in your node's manifest or Hiera data. All configurations are designed to be managed via Hiera for flexibility and environment-specific overrides.

**1. Clone the repository:**

```bash
git clone https://github.com/ggonda/profile_ggonda_cassandr.git /etc/puppetlabs/code/environments/production/modules/profile_ggonda_cassandr
```

**2. Declare the class in your node's Hiera data (e.g., `nodes/yournode.example.com.yaml`):**

```yaml
classes:
  - profile_ggonda_cassandr

# Override default parameters as needed
profile_ggonda_cassandr::cassandra_version: '4.1.10-1'
profile_ggonda_cassandr::java_version: '11'
profile_ggonda_cassandr::cluster_name: 'Production_Cluster_EU'
profile_ggonda_cassandr::seeds: '192.168.1.10,192.168.1.11,192.168.1.12'
profile_ggonda_cassandr::max_heap_size: '4G'
profile_ggonda_cassandr::datacenter: 'eu-west-1'
profile_ggonda_cassandr::rack: 'rack-a'
profile_ggonda_cassandr::cassandra_password: 'YourStrongPassword123!'
profile_ggonda_cassandr::disable_swap_tune_os: true
profile_ggonda_cassandr::enable_range_repair_script: false
```

**3. Run Puppet Agent on the node:**

```bash
puppet agent -tv
```

## Parameters Reference

The following Hiera keys (mapped to class parameters) can be configured:

| Hiera Key                               | Description                                                      | Default Value                 |
| :-------------------------------------- | :--------------------------------------------------------------- | :---------------------------- |
| `profile_ggonda_cassandr::cassandra_version` | The specific version of Cassandra to install.                    | `4.1.10-1`                    |
| `profile_ggonda_cassandr::java_version` | The major version of Java to install.                            | `11`                          |
| `profile_ggonda_cassandr::profile_tag`  | A tag for the profile version, informational.                    | `v2.1.0`                      |
| `profile_ggonda_cassandr::cluster_name` | The name of the Cassandra cluster.                               | `Production Cluster`          |
| `profile_ggonda_cassandr::seeds`        | Comma-separated list of seed node IP addresses.                  | `192.168.1.10,192.168.1.11`   |
| `profile_ggonda_cassandr::max_heap_size`| Maximum JVM heap size for Cassandra (e.g., '2G', '4096M').       | `2G`                          |
| `profile_ggonda_cassandr::datacenter`   | The datacenter name for GossipingPropertyFileSnitch.             | `dc1`                         |
| `profile_ggonda_cassandr::rack`         | The rack name for GossipingPropertyFileSnitch.                   | `rack1`                       |
| `profile_ggonda_cassandr::gc_type`      | JVM Garbage Collector type (e.g., 'G1GC', 'CMS').                | `G1GC`                        |
| `profile_ggonda_cassandr::cassandra_password` | The password for the `cassandra` superuser.                    | `PP/C@ss@ndr@123`             |
| `profile_ggonda_cassandr::data_dir`     | Directory for Cassandra data files.                              | `/var/lib/cassandra/data`     |
| `profile_ggonda_cassandr::commitlog_dir`| Directory for Cassandra commit log files.                        | `/var/lib/cassandra/commitlog`|
| `profile_ggonda_cassandr::disable_swap_tune_os` | Boolean to enable/disable OS swap and sysctl tuning.       | `true`                        |
| `profile_ggonda_cassandr::replace_dead_node_ip` | IP address of a dead node being replaced. Leave empty for normal startup. | `` (empty string)             |
| `profile_ggonda_cassandr::enable_range_repair_script` | Boolean to enable/disable the automated range repair service. | `false`                       |

## Operational Guide

This module deploys several utility scripts to `/usr/local/bin` to assist with Cassandra operations.

### Available Scripts (located in `/usr/local/bin`):

*   `check-versions.sh`: Audits and prints versions of OS, Kernel, Puppet, Java, Cassandra, and Python.
*   `cluster-health.sh`: Checks `nodetool status`, cqlsh connectivity, and native transport port (9042).
*   `repair-node.sh`: Runs `nodetool repair -pr` to repair primary ranges on the node.
*   `cleanup-node.sh`: Runs `nodetool cleanup` to remove data belonging to other nodes.
*   `take-snapshot.sh <keyspace> [table]`: Creates a snapshot of keyspace(s)/table(s). Defaults to all keyspaces if none specified.
*   `drain-node.sh`: Drains data from the node, moving it to other nodes, preparing for shutdown or restart.
*   `rebuild-node.sh <datacenter>`: Rebuilds data on a new node from another datacenter. Requires a datacenter argument.
*   `garbage-collect.sh`: Forces a Major Compaction.
*   `assassinate-node.sh <ip_address>`: Forcibly removes a dead node from the cluster (use with extreme caution!).
*   `upgrade-sstables.sh`: Upgrades SSTables to the latest format if a major Cassandra version upgrade occurred.
*   `backup-to-s3.sh <keyspace> [table]`: (Mock) Creates a snapshot, tars it, and simulates uploading to S3.
*   `prepare-replacement.sh`: Checks gossip info and prepares a new node for replacement operations.
*   `range-repair.sh`: A daemon script that continuously runs `nodetool repair -pr` with a 5-day sleep cycle. Can be managed via systemd if `enable_range_repair_script` is true.

### Example Usage:

```bash
# Check cluster health
/usr/local/bin/cluster-health.sh

# Run a full node repair
/usr/local/bin/repair-node.sh

# Take a snapshot of 'my_keyspace'
/usr/local/bin/take-snapshot.sh my_keyspace

# Stop and start the range repair service (if enabled via Puppet)
sudo systemctl start range-repair
sudo systemctl stop range-repair
```

## Architecture

This module adheres to the Puppet Profile/Role pattern. It serves as a "Profile" module, encapsulating all the necessary Puppet resources, configurations, and scripts required to provision a Cassandra node.

*   **Profile**: `profile_ggonda_cassandr` is a profile that wraps various component modules (or in this case, native Puppet resources) and applies configuration tailored for a Cassandra instance. It defines how Cassandra should be deployed, configured, and managed within an organization's specific context.
*   **Role**: A higher-level module (not included here) would combine one or more profiles to define the complete configuration of a server. For instance, a `role::cassandra_server` might include `profile_ggonda_cassandr` along with other profiles for monitoring agents, backups, etc.

This separation ensures a clear responsibility for each module and promotes reusability, allowing different roles to be composed from the same set of profiles.
