#!/bin/bash
# Script to run 'nodetool cleanup' on the current node.

LOG_FILE="/var/log/cassandra/cleanup-node.log"

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo "  Runs 'nodetool cleanup' on the current Cassandra node to remove data"
  echo "  that no longer belongs to the node's token ranges."
  echo "  Logs cleanup start and end times to $LOG_FILE."
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

log_message "Starting 'nodetool cleanup' at $(timestamp)"
nodetool cleanup 2>&1 | tee -a "$LOG_FILE"
CLEANUP_STATUS=$?
log_message "Finished 'nodetool cleanup' at $(timestamp) with exit status $CLEANUP_STATUS"

exit $CLEANUP_STATUS
