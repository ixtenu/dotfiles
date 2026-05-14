#!/usr/bin/env sh
# recursive file search
set -u

if command -v rg >/dev/null 2>&1; then
	rg --vimgrep "$@"
elif command -v ag >/dev/null 2>&1; then
	ag --nocolor --noheading --nobreak "$@"
else
	no9 grep -Rn "$@"
fi

if [ $? -ne 0 ]; then
	echo Not found 1>&2
fi
