#!/usr/bin/env bash

set -euo pipefail

# Test jq works
TEXT=$(echo '{"test": "test"}' | jq -r .test)
if [[ "${TEXT}" != "test" ]]; then
  echo "jq test failed"
  exit 1
fi

# Simple test to make sure the aws command works
aws configure list

# Testing helper script
source /usr/local/bin/helper.sh
initialize
