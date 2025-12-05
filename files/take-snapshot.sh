#!/bin/bash

# Script: take-snapshot.sh
# Description: Creates a Cassandra snapshot for specified keyspaces and tables.
# If no keyspace/table is specified, it snapshots all keyspaces.

usage() {
  echo "Usage: $(basename "$0") [-h|--help] [<keyspace>] [<table_name>]"
  echo """This script creates a snapshot of Cassandra data.
Arguments:
  <keyspace>   (Optional) The keyspace to snapshot. If omitted, all keyspaces will be snapshotted.
  <table_name> (Optional) The table within the keyspace to snapshot. Requires <keyspace> to be specified.

Options:
  -h, --help   Display this help message and exit.
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
      if [ -z "$KEYSPACE" ]; then
        KEYSPACE="$1"
      elif [ -z "$TABLE" ]; then
        TABLE="$1"
      else
        echo "Error: Too many arguments." >&2
        usage
      fi
      ;;
  esac
  shift
done

LOG_TAG="cassandra-snapshot"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
SNAPSHOT_NAME="puppet-snapshot-$TIMESTAMP"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

SNAPSHOT_CMD="nodetool snapshot -t ${SNAPSHOT_NAME}"

if [ -n "$KEYSPACE" ]; then
  SNAPSHOT_CMD="${SNAPSHOT_CMD} -kf ${KEYSPACE}"
  if [ -n "$TABLE" ]; then
    SNAPSHOT_CMD="${SNAPSHOT_CMD} ${TABLE}"
    log_message INFO "--- Starting snapshot for keyspace '${KEYSPACE}' and table '${TABLE}' with name '${SNAPSHOT_NAME}' ---"
  else
    log_message INFO "--- Starting snapshot for keyspace '${KEYSPACE}' with name '${SNAPSHOT_NAME}' ---"
  fi
else
  log_message INFO "--- Starting snapshot for ALL keyspaces with name '${SNAPSHOT_NAME}' ---"
fi

log_message INFO "Command: ${SNAPSHOT_CMD}"

if command -v nodetool &> /dev/null; then
  START_TIME=$(date +%s)
  ${SNAPSHOT_CMD}
  SNAPSHOT_STATUS=$?
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $SNAPSHOT_STATUS -eq 0 ]; then
    log_message INFO "Snapshot '${SNAPSHOT_NAME}' completed successfully in ${DURATION} seconds."
    exit 0
  else
    log_message ERROR "Snapshot '${SNAPSHOT_NAME}' failed with exit code $SNAPSHOT_STATUS after ${DURATION} seconds."
    exit 1
  fi
else
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi
