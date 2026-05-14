#!/usr/bin/env sh
# add one level of indentation
set -u

usage() {
	echo "usage: $0 [-e] [-E n]" 1>&$1
	echo "Add indentation (by default a tab) to stdin.  With -e, indent with four spaces;" 1>&$1
	echo "with -En, indent with n spaces." 1>&$1
	exit $(($1 - 1))
}

ichars='	' # tab character
while getopts heE: name; do
	case $name in
	e) ichars='    ';; # four spaces
	E)
		ichars=
		for i in $(seq 1 $OPTARG); do
			ichars="${ichars} "
		done;;
	h) usage 1;;
	?) usage 2;;
	esac
done
shift $(($OPTIND - 1))

if [ $# -ne 0 ]; then
	echo "$0: unexpected arguments: $@" 1>&2
	usage 2
fi

sed "s/^/$ichars/"
