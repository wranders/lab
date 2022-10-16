#!/bin/bash

export HISTFILE="/run/.bash_history"
export PS1="[lab-workbox:$(pwd)]$ "

tree(){ exa -T $@; }
export -f tree

$@
