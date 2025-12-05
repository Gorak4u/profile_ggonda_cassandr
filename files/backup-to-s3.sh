#!/bin/bash

# Script: backup-to-s3.sh
# Description: Mocks a Cassandra backup process to S3.
# Creates a snapshot, tars the data, and simulates an S3 upload.

usage() {
  echo "Usage: $(basename "$0") [-h|--help] [<keyspace>] [<table_name>]"
  echo """This script performs a mock Cassandra backup process to S3.
Arguments:
  <keyspace>   (Optional) The keyspace to backup. If omitted, all keyspaces will be backed up.
  <table_name> (Optional) The table within the keyspace to backup. Requires <keyspace>.

Options:
  -h, --help   Display this help message and exit.

This script is a placeholder and only demonstrates the steps. In a real scenario,
it would involve actual S3 client tools (e.g., 'aws s3 cp').
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

LOG_TAG="cassandra-backup-s3"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
SNAPSHOT_NAME="s3-backup-$TIMESTAMP"
CASSANDRA_DATA_DIR="/var/lib/cassandra/data"
BACKUP_TARGET_DIR="/tmp/cassandra_backups"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

# 1. Create a snapshot
log_message INFO "--- Starting Cassandra Snapshot for S3 Backup ---"
SNAPSHOT_CMD="nodetool snapshot -t ${SNAPSHOT_NAME}"
if [ -n "$KEYSPACE" ]; then
  SNAPSHOT_CMD="${SNAPSHOT_CMD} -kf ${KEYSPACE}"
  if [ -n "$TABLE" ]; then
    SNAPSHOT_CMD="${SNAPSHOT_CMD} ${TABLE}"
    log_message INFO "Snapshotting keyspace '${KEYSPACE}', table '${TABLE}'..."
  else
    log_message INFO "Snapshotting keyspace '${KEYSPACE}'..."
  fi
else
  log_message INFO "Snapshotting ALL keyspaces..."
fi

if command -v nodetool &> /dev/null; then
  ${SNAPSHOT_CMD}
  if [ $? -ne 0 ]; then
    log_message ERROR "Snapshot failed. Aborting backup."
    exit 1
  fi
  log_message INFO "Snapshot '${SNAPSHOT_NAME}' created successfully."
else
  log_message ERROR "nodetool command not found. Cannot create snapshot. Aborting backup."
  exit 1
fi

# 2. Tar the snapshot directory
log_message INFO "Archiving snapshot data to tar.gz..."
mkdir -p "$BACKUP_TARGET_DIR"
BACKUP_FILE="${BACKUP_TARGET_DIR}/cassandra_snapshot_${SNAPSHOT_NAME}.tar.gz"

if [ -n "$KEYSPACE" ]; then
  TAR_PATH="${CASSANDRA_DATA_DIR}/${KEYSPACE}/snapshots/${SNAPSHOT_NAME}"
else
  TAR_PATH="${CASSANDRA_DATA_DIR}/*/snapshots/${SNAPSHOT_NAME}" # All keyspaces
fi

# Find actual snapshot directories to tar, in case of all keyspaces
SNAPSHOT_DIRS=()
if [ -n "$KEYSPACE" ]; then
  if [ -d "${CASSANDRA_DATA_DIR}/${KEYSPACE}/snapshots/${SNAPSHOT_NAME}" ]; then
    SNAPSHOT_DIRS+=("${CASSANDRA_DATA_DIR}/${KEYSPACE}/snapshots/${SNAPSHOT_NAME}")
  fi
else
  for dir in "${CASSANDRA_DATA_DIR}"/*/snapshots/"${SNAPSHOT_NAME}"; do
    if [ -d "$dir" ]; then
      SNAPSHOT_DIRS+=("$dir")
    fi
  done
fi

if [ ${#SNAPSHOT_DIRS[@]} -eq 0 ]; then
  log_message ERROR "No snapshot directories found for '${SNAPSHOT_NAME}'. Aborting tar."
  exit 1
fi

tar -czvf "${BACKUP_FILE}" -C "${CASSANDRA_DATA_DIR}" $(printf '%s' "${SNAPSHOT_DIRS[@]##*/var/lib/cassandra/data/}" | xargs -n 1 dirname | xargs -n 1 basename | sed 's/\(.*\)/\1\/snapshots\/'${SNAPSHOT_NAME}/g)

if [ $? -ne 0 ]; then
  log_message ERROR "Tar creation failed. Aborting backup."
  exit 1
fi
log_message INFO "Archive created: ${BACKUP_FILE}"

# 3. Simulate upload to S3
log_message INFO "Simulating upload of ${BACKUP_FILE} to S3..."
# In a real scenario, replace the echo with:
# aws s3 cp "${BACKUP_FILE}" "s3://your-s3-bucket/cassandra-backups/"
sleep 5 # Simulate upload time
echo "aws s3 cp ${BACKUP_FILE} s3://your-s3-bucket/cassandra-backups/"
log_message INFO "Upload simulation complete. Check your S3 bucket for the backup file (if using real 'aws s3 cp')."

# 4. Clear snapshot local data
log_message INFO "Clearing local snapshot data..."
nodetool clearsnapshot -t "${SNAPSHOT_NAME}"
if [ $? -ne 0 ]; then
  log_message WARNING "Failed to clear local snapshot '${SNAPSHOT_NAME}'. Manual cleanup may be required."
fi

log_message INFO "--- Cassandra Backup to S3 Mock Completed Successfully ---"
exit 0
