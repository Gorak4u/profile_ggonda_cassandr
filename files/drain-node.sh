#!/bin/bash

# Script: drain-node.sh
# Description: Drains the local Cassandra node.
# This command flushes all memtables to disk and stops accepting writes without shutting down the JVM.

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo """This script executes 'nodetool drain' for the local Cassandra node.
- Flushes all in-memory data (memtables) to disk (SSTables).
- Stops listening for client connections and shuts down the native transport and Thrift server.
- Useful before a planned shutdown or restart of the Cassandra process.
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

LOG_TAG="cassandra-drain"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

log_message INFO "--- Starting Cassandra Node Drain ---"
log_message INFO "Command: nodetool drain"

if command -v nodetool &> /dev/null; then
  START_TIME=$(date +%s)
  nodetool drain
  DRAIN_STATUS=$?
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $DRAIN_STATUS -eq 0 ]; then
    log_message INFO "Cassandra Node Drain completed successfully in ${DURATION} seconds."
    exit 0
  else
    log_message ERROR "Cassandra Node Drain failed with exit code $DRAIN_STATUS after ${DURATION} seconds."
    exit 1
  fi
else
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi
