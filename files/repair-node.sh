#!/bin/bash

# Script: repair-node.sh
# Description: Runs 'nodetool repair -pr' to repair primary ranges on the local node.
# This helps maintain data consistency and availability.

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo """This script executes 'nodetool repair -pr' for the local Cassandra node.
- It performs a primary range repair, which is often sufficient for regular maintenance.
- Logs the start and end times of the repair operation.
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

LOG_TAG="cassandra-repair"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

log_message INFO "--- Starting Cassandra Primary Range Repair ---"
log_message INFO "Command: nodetool repair -pr"

if command -v nodetool &> /dev/null; then
  START_TIME=$(date +%s)
  nodetool repair -pr
  REPAIR_STATUS=$?
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $REPAIR_STATUS -eq 0 ]; then
    log_message INFO "Cassandra Primary Range Repair completed successfully in ${DURATION} seconds."
    exit 0
  else
    log_message ERROR "Cassandra Primary Range Repair failed with exit code $REPAIR_STATUS after ${DURATION} seconds."
    exit 1
  fi
else
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi
