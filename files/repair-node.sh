#!/bin/bash
# Script to run 'nodetool repair -pr' on the current node.

LOG_FILE="/var/log/cassandra/repair-node.log"

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo "  Runs 'nodetool repair -pr' (primary range) on the current Cassandra node."
  echo "  Logs repair start and end times to $LOG_FILE."
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
fi

log_message "Starting 'nodetool repair -pr' at $(timestamp)"
nodetool repair -pr 2>&1 | tee -a "$LOG_FILE"
REPAIR_STATUS=$?
log_message "Finished 'nodetool repair -pr' at $(timestamp) with exit status $REPAIR_STATUS"

exit $REPAIR_STATUS
