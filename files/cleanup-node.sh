#!/bin/bash

# Script: cleanup-node.sh
# Description: Runs 'nodetool cleanup' on the local Cassandra node.
# This command removes data that no longer belongs to the node after a topology change (e.g., node removal).

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo """This script executes 'nodetool cleanup' for the local Cassandra node.
- It is used to remove data that is no longer owned by this node, typically after a node has been decommissioned or replaced.
- This command does not remove data if the node is still considered to own the data, regardless of replication factor.
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

LOG_TAG="cassandra-cleanup"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

log_message INFO "--- Starting Cassandra Node Cleanup ---"
log_message INFO "Command: nodetool cleanup"

if command -v nodetool &> /dev/null; then
  START_TIME=$(date +%s)
  nodetool cleanup
  CLEANUP_STATUS=$?
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $CLEANUP_STATUS -eq 0 ]; then
    log_message INFO "Cassandra Node Cleanup completed successfully in ${DURATION} seconds."
    exit 0
  else
    log_message ERROR "Cassandra Node Cleanup failed with exit code $CLEANUP_STATUS after ${DURATION} seconds."
    exit 1
  fi
else
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi
