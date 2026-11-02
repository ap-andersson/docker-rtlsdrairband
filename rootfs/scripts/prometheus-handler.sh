#!/bin/sh
# Serves one HTTP request for the rtl_airband stats file. Run by ncat once per connection.

STATS_FILE="${STATS_FILE:-/tmp/rtl_airband_stats.txt}"

# Read the request headers before replying. Closing a socket with unread data makes
# the kernel send a reset, which can make the client drop the response.
while IFS= read -r line; do
    line=$(printf '%s' "$line" | tr -d '\r')
    [ -z "$line" ] && break
done

if [ -r "$STATS_FILE" ]; then
    printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain; version=0.0.4\r\nConnection: close\r\n\r\n'
    cat "$STATS_FILE"
else
    printf 'HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nStats not written yet\n'
fi
