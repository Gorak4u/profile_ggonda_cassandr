#!/bin/bash
# Script to force remove a dead node from the cluster using nodetool assassinate.

NODE_IP=""
LOG_FILE="/var/log/cassandra/assassinate-node.log"

usage() {
  echo "Usage: $(basename "$0") [-h|--help] -ip <node_ip>"
  echo "  Runs 'nodetool assassinate <node_ip>' to force remove a dead node from the cluster."
  echo "  USE WITH EXTREME CAUTION! This command can lead to data loss if used incorrectly."
  echo "  Logs start and end times to $LOG_FILE."
  echo ""
  echo "Options:"
  echo "  -h, --help    Display this help message."
  echo "  -ip <node_ip> REQUIRED: IP address of the node to assassinate."
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -ip)
      if [ -n "$2" ] && [[ "$2" != -* ]]; then
        NODE_IP="$2"
        shift
      else
        echo "Error: Argument for -ip <node_ip> is missing."
        usage
        exit 1
      fi
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Error: Unknown parameter: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [ -z "$NODE_IP" ]; then
  echo "Error: Node IP (-ip) is required."
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
}

log_message "WARNING: Attempting to assassinate node with IP: ${NODE_IP} at $(timestamp)"
log_message "This is a destructive operation and should only be used as a last resort."
log_message "Ensure the node is permanently dead and will not rejoin the cluster."

echo "Are you absolutely sure you want to assassinate node ${NODE_IP}? Type 'yes' to proceed:"
read CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
  log_message "Assassination cancelled by user."
  exit 0
fi

log_message "Confirmed. Executing 'nodetool assassinate ${NODE_IP}'..."
nodetool assassinate "${NODE_IP}" 2>&1 | tee -a "$LOG_FILE"
ASSASSINATE_STATUS=$?
log_message "Finished 'nodetool assassinate ${NODE_IP}' at $(timestamp) with exit status $ASSASSINATE_STATUS"

exit $ASSASSINATE_STATUS
