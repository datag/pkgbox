#!/usr/bin/env bash

[[ $# == 1 ]] || { echo "Usage: ${0##*/} <path> [<prefix>]" >&2; exit 1; }

export LC_ALL=C

SCANPATH=$(readlink -f $1)
IPREFIX=${2-$SCANPATH}

RTLDLIST="/lib/ld-linux.so.2 /lib64/ld-linux-x86-64.so.2"

function parse_line() {
	echo "Library: $@" >&2
	
	local lib
	[[ $# == 4 ]] && lib=$3 || lib=$1
	
	libs+=( $lib )
}

declare -a libs

while read -r f; do
	for rtld in $RTLDLIST; do
		[[ -x $rtld ]] || continue
		
		$rtld --verify "$f"
		case $? in
		[02])
			: # success
			;;
		*)
			# not an ELF or RTLD not suitable? skip it...
			continue
			;;
		esac
	
		echo "Processing: $f" >&2
	
		while read -r l; do
			parse_line $l
		done < <($rtld --list "$f")
		
		# skip other RTLD
		continue
	done
done < <(find "$SCANPATH" -type f -print)


for lib in "${libs[@]}"; do
	echo ${lib/$IPREFIX/"{_PREFIX}/"}
done | sort | uniq -c

