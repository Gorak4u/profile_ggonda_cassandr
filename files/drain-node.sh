#!/bin/bash
# Script to run 'nodetool drain' on the current node.

LOG_FILE="/var/log/cassandra/drain-node.log"

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo "  Runs 'nodetool drain' on the current Cassandra node to flush all memtables"
  echo "  to disk and stop listening for client connections, preparing for shutdown."
  echo "  Logs drain start and end times to $LOG_FILE."
  echo ""
  echo "Options:"
  echo "  -h, --help    Display this help message."
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_message() {
  echo "$(timestamp) $1" | tee -a "$LOG_FILE"
}

if ! command -v nodetool > /dev/null; then
  log_message "Error: nodetool command not found. Please ensure Cassandra is installed."
  exit 1
}

log_message "Starting 'nodetool drain' at $(timestamp)"
nodetool drain 2>&1 | tee -a "$LOG_FILE"
DRAIN_STATUS=$?
log_message "Finished 'nodetool drain' at $(timestamp) with exit status $DRAIN_STATUS"

exit $DRAIN_STATUS
