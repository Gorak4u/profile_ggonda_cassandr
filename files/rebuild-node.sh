#!/bin/bash

# Script: rebuild-node.sh
# Description: Rebuilds data on a Cassandra node from another datacenter.
# This is typically used for adding a new node to an existing datacenter, or replacing a failed node.

usage() {
  echo "Usage: $(basename "$0") [-h|--help] <source_datacenter_name>"
  echo """This script executes 'nodetool rebuild' to stream data from a specified datacenter.
Arguments:
  <source_datacenter_name>  The name of the datacenter to stream data from.
                            This is a mandatory argument.

Options:
  -h, --help                Display this help message and exit.

Example:
  $(basename "$0") dc1
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
      if [ -z "$SOURCE_DC" ]; then
        SOURCE_DC="$1"
      else
        echo "Error: Too many arguments." >&2
        usage
      fi
      ;;
  esac
  shift
done

if [ -z "$SOURCE_DC" ]; then
  echo "Error: Missing required argument <source_datacenter_name>." >&2
  usage
fi

LOG_TAG="cassandra-rebuild"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

log_message INFO "--- Starting Cassandra Node Rebuild from Datacenter: ${SOURCE_DC} ---"
REBUILD_CMD="nodetool rebuild ${SOURCE_DC}"
log_message INFO "Command: ${REBUILD_CMD}"

if command -v nodetool &> /dev/null; then
  START_TIME=$(date +%s)
  ${REBUILD_CMD}
  REBUILD_STATUS=$?
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $REBUILD_STATUS -eq 0 ]; then
    log_message INFO "Cassandra Node Rebuild completed successfully in ${DURATION} seconds."
    exit 0
  else
    log_message ERROR "Cassandra Node Rebuild failed with exit code $REBUILD_STATUS after ${DURATION} seconds."
    exit 1
  fi
else
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi
