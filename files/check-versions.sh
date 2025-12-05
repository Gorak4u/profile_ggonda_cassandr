#!/bin/bash

# Script: check-versions.sh
# Description: Audits and prints versions of key software components on the system.
# Checks OS, Kernel, Puppet, Java, Cassandra, and Python versions.

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo """This script audits and prints the versions of the following components:
- Operating System
- Kernel
- Puppet Agent
- Java Development Kit (JDK)
- Apache Cassandra (via nodetool)
- Python
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

log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

log_info "--- System Version Audit ---"

# 1. Operating System Version
log_info "Checking Operating System version..."
if [ -f /etc/os-release ]; then
  grep -E '^(NAME|VERSION)=' /etc/os-release | sed 's/"//g'
elif [ -f /etc/redhat-release ]; then
  cat /etc/redhat-release
else
  log_error "Could not determine OS version from /etc/os-release or /etc/redhat-release"
fi
echo

# 2. Kernel Version
log_info "Checking Kernel version..."
uname -r
echo

# 3. Puppet Agent Version
log_info "Checking Puppet Agent version..."
if command -v puppet &> /dev/null; then
  puppet --version
else
  log_error "Puppet command not found. Puppet Agent may not be installed or in PATH."
fi
echo

# 4. Java Version
log_info "Checking Java version..."
if command -v java &> /dev/null; then
  java -version 2>&1 | grep -E 'version|openjdk version|Runtime Environment|Java HotSpot' | head -n 1
else
  log_error "Java command not found. Java may not be installed or in PATH."
fi
echo

# 5. Cassandra Version (via nodetool)
log_info "Checking Cassandra version..."
if command -v nodetool &> /dev/null; then
  nodetool version
else
  log_error "nodetool command not found. Cassandra may not be installed or in PATH."
fi
echo

# 6. Python Version
log_info "Checking Python version..."
if command -v python3 &> /dev/null; then
  python3 --version
elif command -v python &> /dev/null; then
  python --version
else
  log_error "Python command not found. Python may not be installed or in PATH."
fi
echo

log_info "--- Audit Complete ---"
