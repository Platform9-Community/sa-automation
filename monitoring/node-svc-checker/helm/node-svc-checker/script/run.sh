#!/usr/bin/env bash

set -o pipefail

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

saveNodeJson() {
  kubectl get nodes "$CHECKER_NODE_NAME" -o json > "$CHECKER_JSON_OUTPUT" || abort
}

readNodeJson() {
  if ! [ -s "$CHECKER_JSON_OUTPUT" ]; then
    err "zero size file: $CHECKER_JSON_OUTPUT"
    abort
  fi
  cat "$CHECKER_JSON_OUTPUT"
}

nodeIsReady() {
  local output
  output=$(readNodeJson | jq -r '.status.conditions[] | select(.type=="Ready") | .status' | tr '[:upper:]' '[:lower:]')
  if [ "$output" == "true" ]; then
    true
  else
    false
  fi
}

nodeIsDrained() {
  count=$(readNodeJson | grep -c "$CHECKER_DRAIN_ANNOTATION_KEY\": \"$CHECKER_DRAIN_ACTIVE_VALUE")
  if [[ $count -gt 0 ]]; then
    true
  else
    false
  fi
}

taintIsApplied() {
  local count
  count=$(readNodeJson | grep -c "key\": \"$1")
  if [[ $count -gt 0 ]]; then
    true
  else
    false
  fi
}

nodeIsCordoned() {
  taintIsApplied "node.kubernetes.io/unschedulable"
}

cordonNodeEnabled() {
  if [ "$CHECKER_CORDON_NODE" == "true" ]; then
    true
  else
    false
  fi
}

drainNodeEnabled() {
  if [ "$CHECKER_DRAIN_NODE" == "true" ]; then
    true
  else
    false
  fi
}

taintNodeEnabled() {
  if [ "$CHECKER_TAINT_NODE" == "true" ]; then
    true
  else
    false
  fi
}

onFailure() {
  warn "Detected the monitored service is unhealthy."
  if nodeIsReady; then
    if cordonNodeEnabled; then
      if ! nodeIsCordoned; then
        warn "Cordoning node $CHECKER_NODE_NAME"
        kubectl cordon "$CHECKER_NODE_NAME" || abort
      fi
    fi
    if drainNodeEnabled; then
      if ! nodeIsDrained; then
        warn "Draining node $CHECKER_NODE_NAME and adding annotation [$CHECKER_DRAIN_ANNOTATION_KEY=$CHECKER_DRAIN_ACTIVE_VALUE]"
        kubectl drain "$CHECKER_NODE_NAME" --ignore-daemonsets=true --delete-emptydir-data || abort
        kubectl annotate --overwrite=true node "$CHECKER_NODE_NAME" "$CHECKER_DRAIN_ANNOTATION_KEY=$CHECKER_DRAIN_ACTIVE_VALUE"
      fi
    fi
    if taintNodeEnabled; then
      if ! taintIsApplied "$CHECKER_TAINT_KEY"; then
        warn "Tainting node $CHECKER_NODE_NAME"
        kubectl taint node "$CHECKER_NODE_NAME" "$CHECKER_TAINT_KEY=$CHECKER_TAINT_VALUE:$CHECKER_TAINT_EFFECT" || abort
      fi
    fi
  fi
}

onSuccess() {
  if nodeIsReady; then
    if cordonNodeEnabled; then
      if nodeIsCordoned; then
        info "Uncordoning node $CHECKER_NODE_NAME"
        kubectl uncordon "$CHECKER_NODE_NAME" || abort
      fi
    fi
    if drainNodeEnabled; then
      if nodeIsDrained; then
        info "Adding annotation [$CHECKER_DRAIN_ANNOTATION_KEY=$CHECKER_DRAIN_NOT_ACTIVE_VALUE] to node $CHECKER_NODE_NAME"
        kubectl annotate --overwrite=true node "$CHECKER_NODE_NAME" "$CHECKER_DRAIN_ANNOTATION_KEY=$CHECKER_DRAIN_NOT_ACTIVE_VALUE"
      fi
    fi
    if taintNodeEnabled; then
      if taintIsApplied "$CHECKER_TAINT_KEY"; then
        info "Removing taint from node $CHECKER_NODE_NAME"
        kubectl taint node "$CHECKER_NODE_NAME" "$CHECKER_TAINT_KEY=$CHECKER_TAINT_VALUE:$CHECKER_TAINT_EFFECT-" || abort
      fi
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

      saveNodeJson

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
      info "PAUSED due to CHECKER_ENABLED environment variable value: false"
    fi
    sleep "$CHECKER_PERIOD"
  done
}

mainLoop "$@"
