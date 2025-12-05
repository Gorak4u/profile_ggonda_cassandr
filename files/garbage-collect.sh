#!/bin/bash

# Script: garbage-collect.sh
# Description: Initiates a major compaction (garbage collection) on Cassandra SSTables.
# This merges SSTables to reclaim disk space and improve read performance.

usage() {
  echo "Usage: $(basename "$0") [-h|--help] [<keyspace>] [<table_name>]"
  echo """This script executes 'nodetool garbagecollect' to force a major compaction.
Arguments:
  <keyspace>   (Optional) The keyspace to garbage collect. If omitted, all keyspaces will be processed.
  <table_name> (Optional) The table within the keyspace to garbage collect. Requires <keyspace>.

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

LOG_TAG="cassandra-gc"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

GC_CMD="nodetool garbagecollect"

if [ -n "$KEYSPACE" ]; then
  GC_CMD="${GC_CMD} ${KEYSPACE}"
  if [ -n "$TABLE" ]; then
    GC_CMD="${GC_CMD} ${TABLE}"
    log_message INFO "--- Starting Major Compaction for keyspace '${KEYSPACE}', table '${TABLE}' ---"
  else
    log_message INFO "--- Starting Major Compaction for keyspace '${KEYSPACE}' ---"
  fi
else
  log_message INFO "--- Starting Major Compaction for ALL keyspaces ---"
fi

log_message INFO "Command: ${GC_CMD}"

if command -v nodetool &> /dev/null; then
  START_TIME=$(date +%s)
  ${GC_CMD}
  GC_STATUS=$?
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [ $GC_STATUS -eq 0 ]; then
    log_message INFO "Major Compaction completed successfully in ${DURATION} seconds."
    exit 0
  else
    log_message ERROR "Major Compaction failed with exit code $GC_STATUS after ${DURATION} seconds."
    exit 1
  fi
else
  log_message ERROR "nodetool command not found. Is Cassandra installed and in PATH?"
  exit 1
fi
