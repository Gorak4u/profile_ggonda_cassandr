#!/bin/bash

# Script: upgrade-sstables.sh
# Description: Upgrades SSTables to the latest format if a major Cassandra version upgrade occurred.
# This is typically run after a rolling upgrade of Cassandra versions.

usage() {
  echo "Usage: $(basename "$0") [-h|--help] [<keyspace>] [<table_name>]"
  echo """This script executes 'nodetool upgradesstables -a' to upgrade SSTables to the current Cassandra version's format.
Arguments:
  <keyspace>   (Optional) The keyspace to upgrade. If omitted, all keyspaces will be processed.
  <table_name> (Optional) The table within the keyspace to upgrade. Requires <keyspace>.

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

LOG_TAG="cassandra-upgrade-sstables"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

UPGRADE_CMD="nodetool upgradesstables -a"

if [ -n "$KEYSPACE" ]; then
  UPGRADE_CMD="${UPGRADE_CMD} ${KEYSPACE}"
  if [ -n "$TABLE" ]; then
    UPGRADE_CMD="${UPGRADE_CMD} ${TABLE}"
    log_message INFO "--- Starting SSTable upgrade for keyspace '${KEYSPACE}', table '${TABLE}' ---"
  else
    log_message INFO "--- Starting SSTable upgrade for keyspace '${KEYSPACE}' ---"
  fi
else
  log_message INFO "--- Starting SSTable upgrade for ALL keyspaces ---"
fi

log_message INFO "Command: ${UPGRADE_CMD}"

if command -v nodetool &> /dev/null; then
  START_TIME=$(date +%s)
  ${UPGRADE_CMD}
  UPGRADE_STATUS=$?
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $UPGRADE_STATUS -eq 0 ]; then
    log_message INFO "SSTable upgrade completed successfully in ${DURATION} seconds."
    exit 0
  else
    log_message ERROR "SSTable upgrade failed with exit code $UPGRADE_STATUS after ${DURATION} seconds."
    exit 1
  fi
else
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi
