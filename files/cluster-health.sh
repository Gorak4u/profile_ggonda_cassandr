#!/bin/bash
# Script to check Cassandra cluster health using nodetool status and cqlsh connection.

LOG_FILE="/var/log/cassandra/cluster-health.log"
CASSANDRA_USER="cassandra" # Default user
CASSANDRA_PASS="PP/C@ss@ndr@123" # Default password

usage() {
  echo "Usage: $(basename "$0") [-h|--help] [-u <user>] [-p <password>]"
  echo "  Checks Cassandra cluster health by querying nodetool status and cqlsh connection."
  echo "  Logs output to stdout and $LOG_FILE."
  echo ""
  echo "Options:"
  echo "  -h, --help    Display this help message."
  echo "  -u <user>     Specify Cassandra username (default: $CASSANDRA_USER)."
  echo "  -p <password> Specify Cassandra password (default: $CASSANDRA_PASS)."
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -u)
      if [ -n "$2" ] && [[ "$2" != -* ]]; then
        CASSANDRA_USER="$2"
        shift
      else
        echo "Error: Argument for -u <user> is missing."
        usage
        exit 1
      fi
      ;;
    -p)
      if [ -n "$2" ] && [[ "$2" != -* ]]; then
        CASSANDRA_PASS="$2"
        shift
      else
        echo "Error: Argument for -p <password> is missing."
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

log_message "--- Starting Cassandra Cluster Health Check ---"

HEALTH_FAILED=0

# 1. Check nodetool status
log_message "Checking 'nodetool status'..."
if command -v nodetool > /dev/null; then
  NODETOOL_STATUS=$(nodetool status 2>&1)
  if echo "$NODETOOL_STATUS" | grep -q "Datacenter: "; then
    log_message "nodetool status: OK"
    echo "$NODETOOL_STATUS" | tee -a "$LOG_FILE"
  else
    log_message "nodetool status: FAILED"
    echo "$NODETOOL_STATUS" | tee -a "$LOG_FILE"
    HEALTH_FAILED=1
  fi
else
  log_message "Error: nodetool command not found."
  HEALTH_FAILED=1
fi

# 2. Check cqlsh connection (native transport port 9042)
log_message "Checking cqlsh connection on port 9042..."
if command -v cqlsh > /dev/null; then
  NODE_IP=$(hostname -I | awk '{print $1}')
  if [ -z "$NODE_IP" ]; then
    log_message "Warning: Could not determine current node IP. Trying localhost."
    NODE_IP="127.0.0.1"
  fi

  if cqlsh "$NODE_IP" 9042 -u "$CASSANDRA_USER" -p "$CASSANDRA_PASS" -e 'SELECT cluster_name FROM system.local;' > /dev/null 2>&1; then
    log_message "cqlsh connection to $NODE_IP:9042 (user: $CASSANDRA_USER): SUCCESS"
  else
    log_message "cqlsh connection to $NODE_IP:9042 (user: $CASSANDRA_USER): FAILED (Check credentials or service status)"
    HEALTH_FAILED=1
  fi
else
  log_message "Error: cqlsh command not found."
  HEALTH_FAILED=1
}

# 3. Check port 9042 listening
log_message "Checking if port 9042 is listening..."
if command -v netstat > /dev/null; then
  if netstat -tln | grep -q ':9042'; then
    log_message "Port 9042 is listening: OK"
  else
    log_message "Port 9042 is NOT listening: FAILED"
    HEALTH_FAILED=1
  fi
else
  log_message "Warning: netstat command not found. Cannot check port status."
}

if [ "$HEALTH_FAILED" == "1" ]; then
  log_message "--- Cassandra Cluster Health Check: FAILED ---"
  exit 1
else
  log_message "--- Cassandra Cluster Health Check: SUCCESS ---"
  exit 0
fi
