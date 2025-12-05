#!/bin/bash

# Script: assassinate-node.sh
# Description: Forcibly removes a dead Cassandra node from the cluster.
# Use with extreme caution as this can lead to data loss if not used properly.

usage() {
  echo "Usage: $(basename "$0") [-h|--help] <dead_node_ip_address>"
  echo """This script executes 'nodetool assassinate' to forcibly remove a dead node.
Arguments:
  <dead_node_ip_address>  The IP address of the dead node to assassinate. This is a mandatory argument.

Options:
  -h, --help              Display this help message and exit.

CRITICAL WARNING: This command should only be used when a node is permanently dead
and cannot be brought back online. Incorrect usage can lead to data inconsistency
or loss if the node eventually rejoins the cluster.
"""
  exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      usage
      ;;
    *)
      if [ -z "$DEAD_NODE_IP" ]; then
        DEAD_NODE_IP="$1"
      else
        echo "Error: Too many arguments." >&2
        usage
      fi
      ;;
  esac
  shift
done

if [ -z "$DEAD_NODE_IP" ]; then
  echo "Error: Missing required argument <dead_node_ip_address>." >&2
  usage
fi

LOG_TAG="cassandra-assassinate"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

log_message WARNING "!!! Initiating Assassination of DEAD NODE: ${DEAD_NODE_IP} !!!"
log_message WARNING "Please ensure this node is permanently down and will not rejoin the cluster."

ASSASSINATE_CMD="nodetool assassinate ${DEAD_NODE_IP}"
log_message INFO "Command: ${ASSASSINATE_CMD}"

# Confirmation step to prevent accidental execution
read -p "Type 'YES' to confirm assassination of ${DEAD_NODE_IP}: " CONFIRMATION
if [[ "$CONFIRMATION" != "YES" ]]; then
  log_message INFO "Assassination cancelled by user."
  exit 0
fi

if command -v nodetool &> /dev/null; then
  START_TIME=$(date +%s)
  ${ASSASSINATE_CMD}
  ASSASSINATE_STATUS=$?
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $ASSASSINATE_STATUS -eq 0 ]; then
    log_message INFO "Node ${DEAD_NODE_IP} successfully assassinated in ${DURATION} seconds."
    log_message WARNING "Data from ${DEAD_NODE_IP} is now gone from the cluster. A repair may be needed on other nodes."
    exit 0
  else
    log_message ERROR "Node assassination for ${DEAD_NODE_IP} failed with exit code $ASSASSINATE_STATUS after ${DURATION} seconds."
    exit 1
  fi
else
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi
