#!/bin/bash
# Script to create a Cassandra snapshot and "upload" it to S3 (mock implementation).

SNAPSHOT_NAME="cassandra_backup_$(date +%Y%m%d%H%M%S)"
KEYSPACE_NAME=""
LOG_FILE="/var/log/cassandra/backup-to-s3.log"
BACKUP_DIR="/var/lib/cassandra/backups" # Temporary local backup storage

usage() {
  echo "Usage: $(basename "$0") [-h|--help] [-t <snapshot_name>] [-k <keyspace>]"
  echo "  Creates a Cassandra snapshot, tars it, and simulates uploading to S3."
  echo ""
  echo "Options:"
  echo "  -h, --help        Display this help message."
  echo "  -t <snapshot_name>  Optional: Name for the snapshot (default: timestamped)."
  echo "  -k <keyspace>     Optional: Keyspace to snapshot. If omitted, all keyspaces are snapshotted."
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
if ! command -v tar > /dev/null; then
  log_message "Error: tar command not found. Please install it."
  exit 1
fi

log_message "Starting Cassandra backup to S3 simulation."
log_message "Snapshot name: ${SNAPSHOT_NAME}"
[ -n "$KEYSPACE_NAME" ] && log_message "Keyspace: ${KEYSPACE_NAME}"

# 1. Take snapshot
SNAPSHOT_COMMAND="nodetool snapshot -t ${SNAPSHOT_NAME}"
if [ -n "$KEYSPACE_NAME" ]; then
  SNAPSHOT_COMMAND="${SNAPSHOT_COMMAND} ${KEYSPACE_NAME}"
fi

log_message "Executing snapshot command: ${SNAPSHOT_COMMAND}"
eval "${SNAPSHOT_COMMAND}" 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
  log_message "Error: Snapshot failed."
  exit 1
fi
log_message "Snapshot '${SNAPSHOT_NAME}' created successfully."

# Determine Cassandra data directory
CASSANDRA_DATA_DIR=$(grep 'data_file_directories:' /etc/cassandra/conf/cassandra.yaml -A 1 | tail -n 1 | sed -e 's/^[[:space:]]*-[[:space:]]*//' -e 's/[[:space:]]*$//')
if [ -z "$CASSANDRA_DATA_DIR" ]; then
  log_message "Error: Could not determine Cassandra data directory from cassandra.yaml."
  exit 1
fi
log_message "Cassandra data directory: $CASSANDRA_DATA_DIR"

SNAPSHOT_PATH="${CASSANDRA_DATA_DIR}/data"
if [ -n "$KEYSPACE_NAME" ]; then
  SNAPSHOT_PATH="${SNAPSHOT_PATH}/${KEYSPACE_NAME}"
fi
SNAPSHOT_PATH="${SNAPSHOT_PATH}"

# 2. Create archive
mkdir -p "$BACKUP_DIR"
ARCHIVE_NAME="${SNAPSHOT_NAME}.tar.gz"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"

log_message "Creating archive: ${ARCHIVE_PATH}"
tar -czf "${ARCHIVE_PATH}" -C "${SNAPSHOT_PATH}" "${SNAPSHOT_NAME}" 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
  log_message "Error: Archiving snapshot failed."
  exit 1
fi
log_message "Snapshot archived to ${ARCHIVE_PATH}"

# 3. Simulate S3 upload
S3_BUCKET="s3://your-cassandra-backup-bucket"
S3_PATH="${S3_BUCKET}/${HOSTNAME}/${ARCHIVE_NAME}"

log_message "Simulating upload to S3: ${S3_PATH}"
echo "Uploading to S3... (This is a mock upload, integrate actual 'aws s3 cp' for real use)" | tee -a "$LOG_FILE"
sleep 5
log_message "Upload simulation complete."

log_message "Cassandra backup to S3 simulation: SUCCESS"
exit 0
