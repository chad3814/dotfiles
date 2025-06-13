#!/bin/bash

ssh=`which ssh`

if [ -f '/Applications/1Password.app/Contents/MacOS/op-ssh-sign' ]; then ssh='/Applications/1Password.app/Contents/MacOS/op-ssh-sign'; fi

exec $ssh $*
