#!/bin/bash
# Script to prepare a node for replacement by checking gossip info and ensuring data is clean.

LOG_FILE="/var/log/cassandra/prepare-replacement.log"

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo "  Prepares a Cassandra node for replacement by checking gossip state and"
  echo "  performing cleanup if necessary. This script does NOT replace the node itself."
  echo "  It is a preliminary check before running 'nodetool replace' or similar."
  echo "  Logs actions to $LOG_FILE."
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
}

log_message "--- Starting Node Replacement Preparation ---"

# 1. Check nodetool gossipinfo for current node state
log_message "Checking 'nodetool gossipinfo' for node state..."
GOSSIP_INFO=$(nodetool gossipinfo 2>&1)
if [ $? -ne 0 ]; then
  log_message "Error: Failed to get gossipinfo. Is Cassandra service running?"
  exit 1
fi

NODE_IP=$(hostname -I | awk '{print $1}')
if [ -z "$NODE_IP" ]; then
  log_message "Error: Could not determine current node IP."
  exit 1
fi

NODE_STATE=$(echo "$GOSSIP_INFO" | grep -A 5 "$NODE_IP" | grep "STATUS:" | awk '{print $2}')
log_message "Current node ($NODE_IP) state in gossip: ${NODE_STATE:-UNKNOWN}"

if [ "$NODE_STATE" != "NORMAL" ]; then
  log_message "Warning: Node is not in NORMAL state. Proceed with caution."
  log_message "It's recommended for a node to be in NORMAL state before replacement preparations."
fi

# 2. Suggest cleanup (if not already done)
log_message "Suggesting 'nodetool cleanup' to remove any orphaned data..."
log_message "Run '/usr/local/bin/cleanup-node.sh' if this hasn't been done recently."

# 3. Suggest draining (if the node is running and about to be shut down)
log_message "Suggesting 'nodetool drain' if the node is running and needs to be shut down cleanly."
log_message "Run '/usr/local/bin/drain-node.sh' before stopping Cassandra service."

log_message "--- Node Replacement Preparation: Complete (Manual steps may be required) ---"
log_message "Review logs and perform 'cleanup-node.sh' and 'drain-node.sh' as appropriate."

exit 0
