#!/bin/sh

echo "$cron bash /app/run.sh > /proc/1/fd/1 2>&1" > /etc/cron.d/root

crond -f