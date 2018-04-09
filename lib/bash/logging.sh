#!/usr/bin/env bash

__INCLUDE_LOGGING_H=y

if [ -z $__INCLUDE_INIT_H ]; then
  source /usr/lib/bash/init.sh
fi

if [ -z $__INCLUDE_COLOR_H ]; then
  source /usr/lib/bash/colors.sh
fi

function .log() {
  local level="$(printf '%-5s' $1)" && shift
  local color="$1" && shift
  local message="$@"

  if [ -t 1 ]; then
    echo -n "$(.fgc $color)"
  fi

  echo -n "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z') [${level}] $message"

  if [ -t 1 ]; then
    echo -n "$(.fgr)"
  fi

  echo
}

function .debug() {
  .log DEBUG green $@
}

function .info() {
  .log INFO cyan $@
}

function .warn() {
  .log WARN yellow $@
}

function .error() {
  .log ERROR red $@
}
