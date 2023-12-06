#!/usr/bin/env bash

set -o pipefail

CHECKER_APP_VERSION="0.1.0"
CHECKER_NODE_NAME=${CHECKER_NODE_NAME:?Nodename not defined}
CHECKER_CMD=${CHECKER_CMD:-/nsc/checker.sh}
CHECKER_PERIOD=${CHECKER_PERIOD:-5}
CHECKER_THRESHOLD=${CHECKER_THRESHOLD:-4}
CHECKER_CORDON_NODE=${CHECKER_CORDON_NODE:-true}
CHECKER_DRAIN_NODE=${CHECKER_DRAIN_NODE:-true}
CHECKER_TAINT_NODE=${CHECKER_TAINT_NODE:-true}
CHECKER_TAINT_KEY=${CHECKER_TAINT_KEY:-aTaint}
CHECKER_TAINT_VALUE=${CHECKER_TAINT_VALUE:-aValue}
CHECKER_TAINT_EFFECT=${CHECKER_TAINT_EFFECT:-anEffect}
CHECKER_DEBUG=${CHECKER_DEBUG:=false}
DRAIN_ANNOTATION_KEY="node-svc-checker-drain-state"
DRAIN_ACTIVE_VALUE="drainActive"
DRAIN_NOT_ACTIVE_VALUE="drainNotActive"

abort() {
  echo "Aborting due to fatal exeception"
  kill -s TERM $$
  exit 1
}

nodeJson() {
  kubectl get nodes "$CHECKER_NODE_NAME" -o json || abort
}

isKubeletUp() {
  nodeJson | jq -r '.status.conditions[] | select(.type=="Ready") | .status' | tr '[:upper:]' '[:lower:]'
}

isNodeDrained() {
  count=$(nodeJson | grep -c "$DRAIN_ANNOTATION_KEY\": \"$DRAIN_ACTIVE_VALUE")
  if [[ $count -gt 0 ]]; then
    echo true
  else
    echo false
  fi
}

isTaintApplied() {
  count=$(nodeJson | grep -c "key\": \"$1")
  if [[ $count -gt 0 ]]; then
    echo true
  else
    echo false
  fi
}

isNodeCordoned() {
  isTaintApplied "node.kubernetes.io/unschedulable"
}

onFailure() {
  echo "⚠ WARN: Detected the monitored service is down!"
  if [ "$(isKubeletUp)" == "true" ]; then
    if [ "$CHECKER_CORDON_NODE" == "true" ]; then
      if [ "$(isNodeCordoned)" == "false" ]; then
        echo "⚠ WARN: Cordoning node $CHECKER_NODE_NAME"
        kubectl cordon "$CHECKER_NODE_NAME" || abort
      fi
    fi
    if [ "$CHECKER_DRAIN_NODE" == "true" ]; then
      if [ "$(isNodeDrained)" == "false" ]; then
        echo "⚠ WARN: Draining node $CHECKER_NODE_NAME and adding annotation [$DRAIN_ANNOTATION_KEY=$DRAIN_ACTIVE_VALUE]"
        kubectl drain "$CHECKER_NODE_NAME" --ignore-daemonsets=true || abort
        kubectl annotate --overwrite=true node "$CHECKER_NODE_NAME" "$DRAIN_ANNOTATION_KEY=$DRAIN_ACTIVE_VALUE"
      fi
    fi
    if [ "$CHECKER_TAINT_NODE" == "true" ]; then
      if [ "$(isTaintApplied "$CHECKER_TAINT_KEY")" == "false" ]; then
        echo "⚠ WARN: Tainting node $CHECKER_NODE_NAME"
        kubectl taint node "$CHECKER_NODE_NAME" "$CHECKER_TAINT_KEY=$CHECKER_TAINT_VALUE:$CHECKER_TAINT_EFFECT" || abort
      fi
    fi
  fi
}

onSuccess() {
  if [ "$(isKubeletUp)" == "true" ]; then
    if [ "$CHECKER_CORDON_NODE" == "true" ]; then
      if [ "$(isNodeCordoned)" == "true" ]; then
        echo "INFO: Uncordoning node $CHECKER_NODE_NAME"
        kubectl uncordon "$CHECKER_NODE_NAME" || abort
      fi
    fi
    if [ "$CHECKER_DRAIN_NODE" == "true" ]; then
      if [ "$(isNodeDrained)" == "true" ]; then
        echo "INFO: Adding annotation [$DRAIN_ANNOTATION_KEY=$DRAIN_NOT_ACTIVE_VALUE] to node $CHECKER_NODE_NAME"
        kubectl annotate --overwrite=true node "$CHECKER_NODE_NAME" "$DRAIN_ANNOTATION_KEY=$DRAIN_NOT_ACTIVE_VALUE"
      fi
    fi
    if [ "$CHECKER_TAINT_NODE" == "true" ]; then
      if [ "$(isTaintApplied "$CHECKER_TAINT_KEY")" == "true" ]; then
        echo "INFO: Removing taint from node $CHECKER_NODE_NAME"
        kubectl taint node "$CHECKER_NODE_NAME" "$CHECKER_TAINT_KEY=$CHECKER_TAINT_VALUE:$CHECKER_TAINT_EFFECT-" || abort
      fi
    fi
  fi
}

mainLoop() {
  counter=0
  while true; do
    echo "INFO: Running $CHECKER_CMD"
    # Ignore any stdout so that any stderr output can be treated as an internal
    # failure of the checker command.
    output=$(bash -c "$CHECKER_CMD 2>&1 1>/dev/null")
    exitCode=$?
    if [ "$output" != "" ]; then
      echo "🚨FATAL: Unexpected stderr output from command [$CHECKER_CMD]: $output"
      abort
    fi
    if [[ $exitCode -ne 0 ]]; then
      (( counter++ ))
      echo "[💥FAIL] non-zero return code. Noticed $counter times. (threshold is $CHECKER_THRESHOLD)"
    else
      counter=0
      echo "[✅OK] return code was zero."
      onSuccess
    fi
    if [[ $counter -ge $CHECKER_THRESHOLD ]]; then
      onFailure
    fi
    sleep "$CHECKER_PERIOD"
  done
}

if ! [ -e "$CHECKER_CMD" ]; then
  echo "🚨FATAL: $CHECKER_CMD command not found!"
  exit 1
elif ! [ -x "$CHECKER_CMD" ]; then
  echo "🚨FATAL: $CHECKER_CMD command not executable!"
  exit 1
fi

if [ "$CHECKER_DEBUG" == "true" ]; then
  set -x
fi

echo "🚀 INFO: Starting version $CHECKER_APP_VERSION with following ENV variables:
+-----------------------------
| CHECKER_DEBUG=${CHECKER_DEBUG}
| CHECKER_NODE_NAME=${CHECKER_NODE_NAME}
| CHECKER_CMD=${CHECKER_CMD}
| CHECKER_PERIOD=${CHECKER_PERIOD}
| CHECKER_THRESHOLD=${CHECKER_THRESHOLD}
| CHECKER_CORDON_NODE=${CHECKER_CORDON_NODE}
| CHECKER_DRAIN_NODE=${CHECKER_DRAIN_NODE}
| CHECKER_TAINT_NODE=${CHECKER_TAINT_NODE}
| CHECKER_TAINT_KEY=${CHECKER_TAINT_KEY}
| CHECKER_TAINT_VALUE=${CHECKER_TAINT_VALUE}
| CHECKER_TAINT_EFFECT=${CHECKER_TAINT_EFFECT}
+-----------------------------

"

mainLoop
