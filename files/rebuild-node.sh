#!/bin/bash
# Script to run 'nodetool rebuild' on a new or replaced node.

DATACENTER_NAME=""
LOG_FILE="/var/log/cassandra/rebuild-node.log"

usage() {
  echo "Usage: $(basename "$0") [-h|--help] [-dc <datacenter_name>]"
  echo "  Runs 'nodetool rebuild' on the current Cassandra node to stream data from"
  echo "  other nodes. Typically used when adding a new node or replacing a dead node."
  echo ""
  echo "Options:"
  echo "  -h, --help        Display this help message."
  echo "  -dc <datacenter>  Optional: Specify the source datacenter for rebuilding."
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -dc)
      if [ -n "$2" ] && [[ "$2" != -* ]]; then
        DATACENTER_NAME="$2"
        shift
      else
        echo "Error: Argument for -dc <datacenter> is missing."
        usage
        exit 1
      fi
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

REBUILD_COMMAND="nodetool rebuild"
if [ -n "$DATACENTER_NAME" ]; then
  REBUILD_COMMAND="${REBUILD_COMMAND} ${DATACENTER_NAME}"
fi

log_message "Starting '${REBUILD_COMMAND}' at $(timestamp)"
eval "${REBUILD_COMMAND}" 2>&1 | tee -a "$LOG_FILE"
REBUILD_STATUS=$?
log_message "Finished '${REBUILD_COMMAND}' at $(timestamp) with exit status $REBUILD_STATUS"

exit $REBUILD_STATUS
