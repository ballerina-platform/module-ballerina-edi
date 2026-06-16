#!/bin/bash

# Copyright (c) 2026, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BAL_EXAMPLES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAL_MODULE_DIR="$BAL_EXAMPLES_DIR/../ballerina"

set -e

case "$1" in
build)
  BAL_CMD="build"
  ;;
run)
  BAL_CMD="run"
  ;;
*)
  echo "Invalid command provided: '$1'. Please provide 'build' or 'run' as the command."
  exit 1
  ;;
esac

# Pack the local ballerina/edi module and push it to the local repository so the
# examples build against the in-repo changes rather than the published version.
echo "Packing and pushing the local ballerina/edi module to the local repository"
(cd "$BAL_MODULE_DIR" && bal pack && bal push --repository=local)

# Build (or run) each example against the local module.
for dir in $(find "$BAL_EXAMPLES_DIR" -mindepth 1 -maxdepth 1 -type d); do
  if [[ "$dir" == *build ]]; then
    continue
  fi
  if [ ! -f "$dir/Ballerina.toml" ]; then
    continue
  fi
  echo "Running 'bal $BAL_CMD' in $dir"
  (cd "$dir" && bal "$BAL_CMD")
done
