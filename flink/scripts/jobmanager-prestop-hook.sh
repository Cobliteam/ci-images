#! /bin/bash
###############################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

set -e

cobli_script="COBLI_PRESTOP_HOOK"

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

stop_job() {
  local cmd_args jm_addr cmd_return job_id pattern savepoint_path
  # TODO get job id from rest api
  job_id="00000000000000000000000000000000"
  log_info "Stopping the job with savepoint"
  cmd_args=("-d" "$job_id")
  if [ "${FLINK_CONF_JOBMANAGER_RPC_ADDRESS:-undefined}" != "undefined" ]; then
    jm_addr="${FLINK_CONF_JOBMANAGER_RPC_ADDRESS}:${FLINK_CONF_REST_PORT}"
    cmd_args=("-m" "$jm_addr" "${cmd_args[@]}")
  fi
  cmd_return=$("$flink_home/bin/flink" stop "${cmd_args[@]}")
  log_debug "$cmd_return"
  pattern="Savepoint completed. Path: file:"
  sed_replace="s/.*$pattern\([^ ]*\)\([ ].*\)*/\1/g"
  savepoint_path=$(echo "$cmd_return" | grep "$pattern" | sed "$sed_replace")
  log_info "Savepoint generated in path: <$savepoint_path>"
  echo "$savepoint_path"
}

create_savepoint_ref() {
  local savepoint
  savepoint="$1"

  echo "# Savepoint path generated by cobli-prestop hook. Do not edit it" \
    > "$savepoint_ref_path"
  echo "file://$savepoint" > "$savepoint_ref_path"

  log_info "Savepoint ref file generated in: <$savepoint_ref_path>"
}

check_rest_api_availability() {
  local jm_addr jm_port
  jm_addr=${FLINK_CONF_JOBMANAGER_RPC_ADDRESS:-"localhost"}
  jm_port=${FLINK_CONF_REST_PORT:-"8081"}
  if nc -z "$jm_addr" "$jm_port" > /dev/null 2>&1 ; then
    return 0
  else
    log_err "Job manager REST API not available"
    return 1
  fi
}

entrypoint() {
  local savepoint_path
  if check_rest_api_availability; then
    echo entrou
    savepoint_path="$(stop_job)"
  fi
  if [ "${savepoint_path:-null}" != "null" ]; then
    create_savepoint_ref "$savepoint_path"
  else
    log_err "Could not generate a savepoint"
    exit 1
  fi
}

entrypoint "$@"
