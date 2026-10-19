#!/bin/sh
# Injects the container's PUB_* environment variables into every prerendered
# page as window.__VERT_ENV__, so the image can be configured at runtime
# without rebuilding. Unset variables fall back to the values baked in at
# build time. Run automatically by the nginx image's entrypoint on start.

set -eu

ROOT="${VERT_HTML_ROOT:-/usr/share/nginx/html}"

json=""
for name in $(env | sed -n 's/^\(PUB_[A-Z0-9_]*\)=.*/\1/p' | sort -u); do
	# escape for a JS string inside a <script> tag
	value=$(printenv "$name" | tr -d '\r\n' |
		sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/</\\u003c/g')
	json="${json:+$json,}\"$name\":\"$value\""
done

export VERT_ENV_SCRIPT="<script id=\"vert-env\">window.__VERT_ENV__={$json};</script>"

find "$ROOT" -type f -name '*.html' | while read -r file; do
	# drop the line injected on a previous start, then add a fresh one after <head>
	awk '
		/<script id="vert-env">/ { next }
		{ print }
		!done && /<head>/ { print ENVIRON["VERT_ENV_SCRIPT"]; done = 1 }
	' "$file" >"$file.tmp"
	mv "$file.tmp" "$file"
done

echo "$0: injected runtime config ($(echo "$json" | grep -o '"PUB_[A-Z0-9_]*"' | tr -d '"' | tr '\n' ' '))"
