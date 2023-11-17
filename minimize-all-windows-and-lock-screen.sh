#!/bin/bash

for window in $(xdotool search --onlyvisible --name ".*")
do
  xdotool windowminimize "$window"
done

loginctl lock-session
