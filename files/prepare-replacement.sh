#!/bin/bash

# Script: prepare-replacement.sh
# Description: Checks gossip information and provides guidance for replacing a Cassandra node.
# This script helps ensure that the replacement process is started correctly.

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo """This script assists in preparing for a Cassandra node replacement.
- It checks the current gossip state to identify dead or removed nodes.
- Provides instructions on how to start a new node as a replacement.
"""
  exit 0
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

LOG_TAG="cassandra-replace-prep"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

log_message INFO "--- Preparing for Cassandra Node Replacement ---"

if ! command -v nodetool &> /dev/null; then
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi

# 1. Check nodetool status
log_message INFO "Checking current cluster status via 'nodetool status'..."
nodetool status
if [ $? -ne 0 ]; then
  log_message ERROR "'nodetool status' failed. Ensure Cassandra is running on at least one node in the cluster."
  exit 1
fi

# 2. Check gossip info for dead or removed nodes
log_message INFO "Checking 'nodetool gossipinfo' for dead or removed nodes..."
if nodetool gossipinfo | grep -E '(STATUS: DOWN|STATUS: REMOVED)'; then
  log_message WARNING "Detected DOWN or REMOVED nodes in gossipinfo. Verify if the node you intend to replace is truly gone."
  log_message INFO "Consider running 'nodetool assassinate <ip_address>' on a healthy node if the old node is permanently dead."
else
  log_message INFO "No DOWN or REMOVED nodes detected in gossipinfo. Cluster appears stable."
fi

# 3. Provide guidance for replacement
log_message INFO "
--- Node Replacement Guidance ---

To replace a dead Cassandra node with a new node at the same IP address:
1.  Ensure the old node is permanently offline and its data directories are cleared.
2.  Provision the new node with the same IP address and necessary Cassandra configuration.
3.  Start Cassandra on the new node with the 'replace_address' JVM option set to the old node's IP.
    This can be done by setting the 'profile_ggonda_cassandr::replace_dead_node_ip' Hiera parameter.
    Example: -Dcassandra.replace_address_first_boot=<dead_node_ip_address>
4.  Allow the new node to stream data and catch up with the cluster.
5.  Verify the new node's status with 'nodetool status'.

Example Puppet Hiera configuration for replacement (assuming the IP of the dead node was 192.168.1.50):
profile_ggonda_cassandr::replace_dead_node_ip: '192.168.1.50'

After replacement is complete and the new node is healthy, clear the 'replace_dead_node_ip' Hiera parameter
to prevent accidental future replacements.
"

log_message INFO "--- Preparation Complete. Proceed with replacement based on the guidance above. ---"
exit 0
