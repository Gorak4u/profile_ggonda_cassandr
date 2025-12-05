#!/bin/bash
# Script to check and print versions of OS, Kernel, Puppet, Java, Cassandra, and Python.

usage() {
  echo "Usage: $(basename "$0") [-h|--help]"
  echo "  Checks and prints versions of various components related to Cassandra."
  echo ""
  echo "Options:"
  echo "  -h, --help    Display this help message."
  echo ""
  echo "Components checked:"
  echo "  - Operating System"
  echo "  - Kernel"
  echo "  - Puppet"
  echo "  - Java"
  echo "  - Cassandra (nodetool)"
  echo "  - Python"
}

# Parse command line arguments
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

echo "--- System Versions ---"

# OS Version
echo -n "Operating System: "
if [ -f /etc/os-release ]; then
  grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g' | sed 's/"//g'
else
  echo "Not found (/etc/os-release)"
fi

# Kernel Version
echo -n "Kernel Version:   "
uname -r

# Puppet Version
echo -n "Puppet Version:   "
if command -v puppet > /dev/null; then
  puppet -V
else
  echo "Not installed"
fi

# Java Version
echo -n "Java Version:     "
if command -v java > /dev/null; then
  java -version 2>&1 | grep "version" | head -n 1
else
  echo "Not installed"
fi

# Cassandra Version (via nodetool)
echo -n "Cassandra Version:"
if command -v nodetool > /dev/null; then
  nodetool version 2>/dev/null | grep "ReleaseVersion" | awk '{print $NF}'
else
  echo "Not installed (nodetool not found)"
fi

# Python Version
echo -n "Python Version:   "
if command -v python3 > /dev/null; then
  python3 --version
elif command -v python > /dev/null; then
  python --version
else
  echo "Not installed"
fi

echo "-----------------------"
