#!/bin/bash
# Script to take a Cassandra snapshot using nodetool.

SNAPSHOT_NAME=""
KEYSPACE_NAME=""
TABLE_NAME=""
LOG_FILE="/var/log/cassandra/snapshot.log"

usage() {
  echo "Usage: $(basename "$0") [-h|--help] -t <snapshot_name> [-k <keyspace>] [-tb <table>]"
  echo "  Takes a snapshot of Cassandra data."
  echo ""
  echo "Options:"
  echo "  -h, --help        Display this help message."
  echo "  -t <snapshot_name>  REQUIRED: Name for the snapshot."
  echo "  -k <keyspace>     Optional: Keyspace to snapshot. If omitted, all keyspaces are snapshotted."
  echo "  -tb <table>       Optional: Table(s) within the keyspace to snapshot. Requires -k."
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -t)
      if [ -n "$2" ] && [[ "$2" != -* ]]; then
        SNAPSHOT_NAME="$2"
        shift
      else
        echo "Error: Argument for -t <snapshot_name> is missing."
        usage
        exit 1
      fi
      ;;
    -k)
      if [ -n "$2" ] && [[ "$2" != -* ]]; then
        KEYSPACE_NAME="$2"
        shift
      else
        echo "Error: Argument for -k <keyspace> is missing."
        usage
        exit 1
      fi
      ;;
    -tb)
      if [ -n "$2" ] && [[ "$2" != -* ]]; then
        TABLE_NAME="$2"
        shift
      else
        echo "Error: Argument for -tb <table> is missing."
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

if [ -z "$SNAPSHOT_NAME" ]; then
  echo "Error: Snapshot name (-t) is required."
  usage
  exit 1
fi

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

SNAPSHOT_COMMAND="nodetool snapshot -t ${SNAPSHOT_NAME}"

if [ -n "$KEYSPACE_NAME" ]; then
  SNAPSHOT_COMMAND="${SNAPSHOT_COMMAND} ${KEYSPACE_NAME}"
  if [ -n "$TABLE_NAME" ]; then
    SNAPSHOT_COMMAND="${SNAPSHOT_COMMAND} ${TABLE_NAME}"
  fi
fi

log_message "Starting snapshot '${SNAPSHOT_NAME}' at $(timestamp)"
log_message "Executing command: ${SNAPSHOT_COMMAND}"

eval "${SNAPSHOT_COMMAND}" 2>&1 | tee -a "$LOG_FILE"
SNAPSHOT_STATUS=$?

log_message "Finished snapshot '${SNAPSHOT_NAME}' at $(timestamp) with exit status $SNAPSHOT_STATUS"

exit $SNAPSHOT_STATUS
