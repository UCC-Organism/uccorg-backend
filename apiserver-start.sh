#!/bin/sh
PATH=$PATH:/usr/local/bin
cd /home/uccorganism/uccorg-backend
while true; do
  if nc -z localhost 8080; then
    exit 0
  fi
  git pull
  coffee uccorg-backend.coffee >> uccorg-backend.log 2>&1
done
