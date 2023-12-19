#!/usr/bin/env bash

set -o pipefail

NODE_IS_DRAINED=false
NODE_IS_CORDONED=false
NODE_IS_TAINTED=false
PROM_STATUS=127 # 0 == good, 1 == failed, 127 == unknown
PROM_METRIC_DIR="/metrics"
PROM_STATUS_FILE="$PROM_METRIC_DIR/index.txt"

logdate() {
  date "+%y/%m/%d %H:%M:%S"
}

colorize() {
  local color="32" # default
  case $1 in
    red|err|error)
      color="31"
      ;;
    green|ok)
      color="32"
      ;;
    yellow|warn)
      color="33"
      ;;
  esac
  shift

  echo -en "\033[1;${color}m"
  echo -en "$*"
  echo -en "\033[0m"
}

info() {
  >&2 echo -e "$(logdate) $(colorize green INFO[ℹ]: "$*")"
}

err() {
  >&2 echo -e "$(logdate) $(colorize red ERROR[❌]: "$*")"
}

warn() {
  >&2 echo -e "$(logdate) $(colorize yellow WARN[⚠️]: "$*")"
}

abort() {
  err "Aborting due to fatal exception"
  kill -s TERM $$
  exit 1
}

savePromStatus() {
  info "Saving status: $PROM_STATUS to $PROM_STATUS_FILE"
  echo "node_svc_checker_check_status $PROM_STATUS" > $PROM_STATUS_FILE
}

onFailure() {
  PROM_STATUS=1
  warn "Detected the monitored service is unhealthy."
  if [ "$CHECKER_CORDON_NODE" == "true" ]; then
    if ! $NODE_IS_CORDONED; then
      warn "Cordoning node $CHECKER_NODE_NAME"
      kubectl cordon "$CHECKER_NODE_NAME" || abort
      NODE_IS_CORDONED=true
    fi
  fi
  if [ "$CHECKER_DRAIN_NODE" == "true" ]; then
    if ! $NODE_IS_DRAINED; then
      warn "Draining node $CHECKER_NODE_NAME"
      kubectl drain "$CHECKER_NODE_NAME" --ignore-daemonsets=true --delete-emptydir-data || abort
      NODE_IS_DRAINED=true
    fi
  fi
  if [ "$CHECKER_TAINT_NODE" == "true" ]; then
    if ! $NODE_IS_TAINTED; then
      warn "Tainting node $CHECKER_NODE_NAME"
      kubectl taint node "$CHECKER_NODE_NAME" "$CHECKER_TAINT_KEY=$CHECKER_TAINT_VALUE:$CHECKER_TAINT_EFFECT" || abort
      NODE_IS_TAINTED=true
    fi
  fi
}

onSuccess() {
  PROM_STATUS=0
  if [ "$CHECKER_CORDON_NODE" == "true" ]; then
    if $NODE_IS_CORDONED; then
      info "Uncordoning node $CHECKER_NODE_NAME"
      kubectl uncordon "$CHECKER_NODE_NAME" || abort
      NODE_IS_CORDONED=false
    fi
  fi
  if [ "$CHECKER_DRAIN_NODE" == "true" ]; then
    if $NODE_IS_DRAINED; then
      NODE_IS_DRAINED=false
    fi
  fi
  if [ "$CHECKER_TAINT_NODE" == "true" ]; then
    if $NODE_IS_TAINTED; then
      info "Removing taint from node $CHECKER_NODE_NAME"
      kubectl taint node "$CHECKER_NODE_NAME" "$CHECKER_TAINT_KEY=$CHECKER_TAINT_VALUE:$CHECKER_TAINT_EFFECT-" || abort
      NODE_IS_TAINTED=false
    fi
  fi
}

dumpConfig() {
  echo "🚀 Current Settings 🚀
+-----------------------------+
$(set | sort | grep "^CHECKER_")
+-----------------------------+

"
}

array_contains() {
  local array="$1[@]"
  local seeking=$2
  local in=1
  for element in "${!array}"; do
    if [[ $element == "$seeking" ]]; then
      in=0
      break
    fi
  done
  return $in
}

mainLoop() {
  CHECKER_CONFIG_PATH=${1:?Full path to config file must be present as first argument!}

  local counter=0
  local md5_orig

  while true; do
    savePromStatus

    local md5_new
    md5_new=$(md5sum "$CHECKER_CONFIG_PATH")
    if [ "$md5_new" != "$md5_orig" ]; then
      info "Loading Configuration Values.."
      # shellcheck disable=SC1090
      source "$CHECKER_CONFIG_PATH"
      md5_orig="$md5_new"
      dumpConfig
    fi

    if [ "$CHECKER_ENABLED" == "true" ]; then
      if ! [ -e "$CHECKER_CMD" ]; then
        err "FATAL: $CHECKER_CMD command not found!"
        exit 1
      elif ! [ -x "$CHECKER_CMD" ]; then
        err "FATAL: $CHECKER_CMD command not executable!"
        exit 1
      fi
      if [ "$CHECKER_DEBUG" == "true" ]; then
        set -x
      else
        set +x
      fi

      local msg="$CHECKER_CMD $CHECKER_ARGS"
      # Ignore any stdout so that any stderr output can be treated as an internal
      # failure of the checker command.
      local output
      output=$(bash -c "$CHECKER_CMD $CHECKER_ARGS 2>&1 1>/dev/null")
      local exitCode=$?
      if [ "$output" != "" ]; then
        err "FATAL: Unexpected stderr output from command [$CHECKER_CMD]: $output"
        abort
      fi
      if array_contains CHECKER_OK_RETURN_CODES_ARRAY "${exitCode}"; then
        counter=0
        info "$msg::exit code $exitCode is in list [$CHECKER_OK_RETURN_CODES_CSV]"
        onSuccess
      else
        (( counter++ ))
        warn "$msg::exit code $exitCode is not in list [$CHECKER_OK_RETURN_CODES_CSV]. Noticed $counter times. (threshold is $CHECKER_THRESHOLD)"
      fi
      if [[ $counter -ge $CHECKER_THRESHOLD ]]; then
        onFailure
      fi
    else
      # reset to good state
      onSuccess

      info "PAUSED due to CHECKER_ENABLED environment variable value: false"
    fi
    sleep "$CHECKER_PERIOD"
  done
}

mainLoop "$@"
