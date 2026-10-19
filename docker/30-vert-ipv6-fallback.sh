#!/bin/sh
# nginx refuses to start when IPv6 is disabled on the host, so drop the
# IPv6 listener in that case (same check as the nginx image's own scripts).

set -eu

CONF=/etc/nginx/conf.d/default.conf

if [ ! -f /proc/net/if_inet6 ] && grep -q 'listen \[::\]' "$CONF"; then
	sed -i '/listen \[::\]/d' "$CONF"
	echo "$0: IPv6 not available, removed IPv6 listener from $CONF"
fi
