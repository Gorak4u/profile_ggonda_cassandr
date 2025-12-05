#!/bin/bash

# Script: cluster-health.sh
# Description: Checks the health of the Cassandra cluster and local node.
# Verifies nodetool status, cqlsh connectivity, and native transport port (9042).

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo """This script performs a basic health check for the Cassandra cluster:
- Runs 'nodetool status' to check node and cluster status.
- Attempts to connect to cqlsh locally.
- Checks if port 9042 (native transport) is listening.
Logs status to stdout and syslog.
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
      echo "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

LOG_TAG="cassandra-health-check"

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

check_nodetool_status() {
  log_message INFO "Running nodetool status..."
  if command -v nodetool &> /dev/null; then
    NODETOOL_OUTPUT=$(nodetool status 2>&1)
    if [ $? -eq 0 ]; then
      log_message INFO "Nodetool status successful:\n$NODETOOL_OUTPUT"
      echo "$NODETOOL_OUTPUT"
    else
      log_message ERROR "Nodetool status failed:\n$NODETOOL_OUTPUT"
      echo "$NODETOOL_OUTPUT"
      return 1
    fi
  else
    log_message ERROR "nodetool command not found."
    return 1
  fi
  return 0
}

check_cqlsh_connection() {
  log_message INFO "Attempting cqlsh connection..."
  if command -v cqlsh &> /dev/null; then
    CQLSH_OUTPUT=$(cqlsh -u cassandra -p cassandra -e 'DESCRIBE CLUSTER;' 2>&1)
    if [ $? -eq 0 ] && echo "$CQLSH_OUTPUT" | grep -q "Cluster: "; then
      log_message INFO "cqlsh connection successful."
    else
      log_message ERROR "cqlsh connection failed.\n$CQLSH_OUTPUT"
      return 1
    fi
  else
    log_message ERROR "cqlsh command not found."
    return 1
  fi
  return 0
}

check_port_9042() {
  log_message INFO "Checking if native transport port 9042 is listening..."
  if command -v ss &> /dev/null; then
    if ss -ltn | grep -q ":9042 "; then
      log_message INFO "Port 9042 is listening."
    else
      log_message ERROR "Port 9042 is NOT listening."
      return 1
    fi
  elif command -v netstat &> /dev/null; then
    if netstat -ltn | grep -q ":9042 "; then
      log_message INFO "Port 9042 is listening."
    else
      log_message ERROR "Port 9042 is NOT listening."
      return 1
    fi
  else
    log_message WARNING "Neither 'ss' nor 'netstat' found. Cannot check port 9042."
    return 1
  fi
  return 0
}

# Main execution
overall_status=0

log_message INFO "--- Starting Cassandra Cluster Health Check ---"

check_nodetool_status || overall_status=1
check_cqlsh_connection || overall_status=1
check_port_9042 || overall_status=1

if [ $overall_status -eq 0 ]; then
  log_message INFO "--- Cassandra Cluster Health Check: SUCCESS ---"
  exit 0
else
  log_message ERROR "--- Cassandra Cluster Health Check: FAILED ---"
  exit 1
fi
