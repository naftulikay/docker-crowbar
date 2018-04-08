#!/usr/bin/env bash

__INCLUDE_INIT_H=y

function .is-a-tty() {
  test -t 1
}
