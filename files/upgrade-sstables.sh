#!/bin/bash
# Script to run 'nodetool upgradesstables' on a node.

KEYSPACE_NAME=""
TABLE_NAME=""
LOG_FILE="/var/log/cassandra/upgrade-sstables.log"

usage() {
  echo "Usage: $(basename "$0") [-h|--help] [-k <keyspace>] [-tb <table>]"
  echo "  Runs 'nodetool upgradesstables -a' (all SSTables) on a Cassandra node."
  echo "  This command upgrades SSTables on a node to the current (newest) format."
  echo "  Logs start and end times to $LOG_FILE."
  echo ""
  echo "Options:"
  echo "  -h, --help        Display this help message."
  echo "  -k <keyspace>     Optional: Keyspace to upgrade SSTables for."
  echo "  -tb <table>       Optional: Table(s) within the keyspace to upgrade. Requires -k."
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
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

UPGRADE_COMMAND="nodetool upgradesstables -a"

if [ -n "$KEYSPACE_NAME" ]; then
  UPGRADE_COMMAND="${UPGRADE_COMMAND} ${KEYSPACE_NAME}"
  if [ -n "$TABLE_NAME" ]; then
    UPGRADE_COMMAND="${UPGRADE_COMMAND} ${TABLE_NAME}"
  fi
fi

log_message "Starting '${UPGRADE_COMMAND}' at $(timestamp)"
eval "${UPGRADE_COMMAND}" 2>&1 | tee -a "$LOG_FILE"
UPGRADE_STATUS=$?
log_message "Finished '${UPGRADE_COMMAND}' at $(timestamp) with exit status $UPGRADE_STATUS"

exit $UPGRADE_STATUS
