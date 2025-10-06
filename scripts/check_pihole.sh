#!/bin/bash
# check_pihole.sh - keepalived health check for Pi-hole
# Exit codes: 0 = healthy, non-zero = fail

set -e

# 1) DNS check (local resolver)
dig @127.0.0.1 pi.hole +short >/dev/null 2>&1
DNS_OK=$?

# 2) FTL process check (recommended)
pgrep pihole-FTL >/dev/null 2>&1
FTL_OK=$?

# 3) Web UI check (local HTTP request)
curl -sS --connect-timeout 2 http://127.0.0.1/admin/ > /dev/null 2>&1
UI_OK=$?

# Combine checks - require DNS and at least one of FTL or UI
if [ $DNS_OK -eq 0 ] && { [ $FTL_OK -eq 0 ] || [ $UI_OK -eq 0 ]; }; then
	exit 0
else
	# Optional: log reason for debugging
	echo "Health check failed: DNS=$DNS_OK, FTL=$FTL_OK, UI=$UI_OK" >&2
	exit 1
fi
