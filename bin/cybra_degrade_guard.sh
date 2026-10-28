#!/data/data/com.termux/files/usr/bin/bash
printf '%s' '{"type":"degrade_guard_task"}' | redis-cli -x rpush cybra:parliament:queue >/dev/null
