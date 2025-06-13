#!/bin/bash

xauth=`which xauth`
if [ ! -f "$xauth" ]; then echo "No xauth found" >&2; exit 1; fi

exec $xauth $*
