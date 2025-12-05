#!/bin/bash
# Daemon script to continuously run 'nodetool repair -pr' and sleep for a period.

PID_FILE="/var/run/cassandra_range_repair.pid"
LOG_FILE="/var/log/cassandra/range-repair.log"
SLEEP_SECONDS=432000 # 5 days (5 * 24 * 60 * 60)

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_message() {
  echo "$(timestamp) $1" | tee -a "$LOG_FILE"
}

run_repair_loop() {
  log_message "Starting continuous range repair loop. Repair will run every ${SLEEP_SECONDS} seconds."
  while true; do
    log_message "Initiating 'nodetool repair -pr' at $(timestamp)"
    if command -v nodetool > /dev/null; then
      nodetool repair -pr 2>&1 | tee -a "$LOG_FILE"
      REPAIR_STATUS=$?
      if [ $REPAIR_STATUS -eq 0 ]; then
        log_message "Repair completed successfully."
      else
        log_message "Repair failed with exit status $REPAIR_STATUS. Retrying after sleep."
      fi
    else
      log_message "Error: nodetool command not found. Cannot perform repair. Exiting loop."
      exit 1
    fi

    log_message "Sleeping for ${SLEEP_SECONDS} seconds..."
    sleep "$SLEEP_SECONDS"
  done
}

start() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null; then
      log_message "Service is already running with PID $PID."
      exit 0
    else
      log_message "Stale PID file found. Removing $PID_FILE."
      rm -f "$PID_FILE"
    fi
  }

  log_message "Starting range repair service."
  (
    run_repair_loop
  ) & # Run in background
  echo $! > "$PID_FILE" # Capture PID of the immediately preceding background command
  if [ $? -eq 0 ]; then
    log_message "Service started with PID $(cat "$PID_FILE")."
    exit 0
  else
    log_message "Failed to start service."
    exit 1
  fi
}

stop() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null; then
      log_message "Stopping range repair service (PID $PID)."
      kill "$PID"
      if [ $? -eq 0 ]; then
        rm -f "$PID_FILE"
        log_message "Service stopped."
        exit 0
      else
        log_message "Failed to stop service with kill $PID."
        exit 1
      fi
    else
      log_message "Service not running, but PID file $PID_FILE exists. Removing stale PID file."
      rm -f "$PID_FILE"
      exit 0
    fi
  else
    log_message "Service is not running (PID file not found)."
    exit 0
  fi
}

status() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null; then
      log_message "Range repair service is running with PID $PID."
      exit 0
    else
      log_message "Range repair service is not running, but PID file $PID_FILE exists (stale)."
      exit 3 # LSB: program is not running but status file exists
    fi
  else
    log_message "Range repair service is not running (PID file not found)."
    exit 3 # LSB: program is not running
  fi
}

restart() {
  stop
  start
}

usage() {
  echo "Usage: $(basename "$0") {start|stop|restart|status|--help}"
  echo "  Manages the Cassandra range repair daemon. Runs 'nodetool repair -pr' in a loop."
  echo ""
  echo "Commands:"
  echo "  start     Start the repair daemon."
  echo "  stop      Stop the repair daemon."
  echo "  restart   Restart the repair daemon."
  echo "  status    Check the status of the repair daemon."
  echo "  --help    Display this help message."
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
  --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown command: $1"
    usage
    exit 1
    ;;
esac
