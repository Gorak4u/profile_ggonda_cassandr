#!/bin/bash

# Script: range-repair.sh
# Description: A daemon script to periodically run 'nodetool repair -pr'.
# This script ensures continuous consistency maintenance for Cassandra data.

usage() {
  echo "Usage: $(basename "$0") {start|stop|restart|status}"
  echo """This script manages a daemon process that runs 'nodetool repair -pr' in a loop.
Commands:
  start    : Starts the range repair daemon.
  stop     : Stops the range repair daemon.
  restart  : Restarts the range repair daemon.
  status   : Checks the status of the range repair daemon.

Interval: The repair runs once every 5 days (432000 seconds).
"""
  exit 1
}

LOG_TAG="cassandra-range-repair"
PID_FILE="/var/run/range-repair.pid"
REPAIR_INTERVAL_SECONDS=432000 # 5 days

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  logger -t "$LOG_TAG" "[$level] $message"
}

run_repair_loop() {
  log_message INFO "Range repair daemon started with PID $$"
  echo $$ > "$PID_FILE"

  while true; do
    log_message INFO "Starting 'nodetool repair -pr' at $(date)"
    if command -v nodetool &> /dev/null; then
      nodetool repair -pr
      REPAIR_STATUS=$?
      if [ $REPAIR_STATUS -eq 0 ]; then
        log_message INFO "'nodetool repair -pr' completed successfully."
      else
        log_message ERROR "'nodetool repair -pr' failed with exit code $REPAIR_STATUS."
      fi
    else
      log_message ERROR "nodetool command not found. Cannot perform repair."
    fi

    log_message INFO "Sleeping for ${REPAIR_INTERVAL_SECONDS} seconds before next repair."
    sleep "$REPAIR_INTERVAL_SECONDS"
  done
}

start() {
  if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    log_message INFO "Range repair daemon is already running (PID: $(cat "$PID_FILE"))."
    exit 0
  fi
  log_message INFO "Starting range repair daemon..."
  run_repair_loop & # Run in background
  if [ $? -eq 0 ]; then
    log_message INFO "Range repair daemon started."
  else
    log_message ERROR "Failed to start range repair daemon."
    exit 1
  fi
}

stop() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      log_message INFO "Stopping range repair daemon (PID: ${PID})..."
      kill "$PID"
      rm -f "$PID_FILE"
      log_message INFO "Range repair daemon stopped."
    else
      log_message WARNING "PID file exists but process not found. Cleaning up PID file."
      rm -f "$PID_FILE"
    fi
  else
    log_message INFO "Range repair daemon not running (PID file not found)."
  fi
}

status() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      log_message INFO "Range repair daemon is running (PID: ${PID})."
      exit 0
    else
      log_message WARNING "PID file exists but process is not running. PID file might be stale. PID: ${PID}."
      exit 1
    fi
  else
    log_message INFO "Range repair daemon is not running (PID file not found)."
    exit 1
  fi
}

restart() {
  stop
  start
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  status)
    status
    ;;
  *)
    usage
    ;;
esac

exit 0
