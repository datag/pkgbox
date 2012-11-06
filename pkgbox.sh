#!/usr/bin/env bash

set -e  #x

# absolute location of script
declare -r PKGBOX_PATH="$(dirname "$(readlink -f "$BASH_SOURCE")")"

# print usage (stdout)
function pkgbox_usage()
{
	echo "Usage: ${0##*/} <TODO>"
}

# print message (stderr) and die
# @param string... msg
# @param [int=1] exitcode
function pkgbox_die()
{
	local exitcode=1 msg=
	if [[ $# == 0 ]]; then
		exit $exitcode
	elif [[ $# == 1 ]]; then
		msg="$1"
	else
		msg="${@:1:$# - 1}"
		exitcode="${@:$#}"
	fi
	
	echo "[pkgbox die] $msg" >&2
	exit $exitcode
}

# includes functionality
function pkgbox_include()
{
	local file="$PKGBOX_PATH/$1"
	[[ -r $file && -f $file ]] || pkgbox_die "Include file '$1' not found" 2
	source "$file"
}

# tests if function exists
# @return int non-zero on error
function pkgbox_is_function()
{
	declare -F "$1" >/dev/null
}

################################################################################

# check for valid invocation
if [[ $# < 1 ]]; then
	pkgbox_die "$(pkgbox_usage)" 1
fi

# include basic libs
pkgbox_include "include/basic.sh"

pkgbox_is_function pkgbox_usage || pkgbox_die "pkgbox_usage is no function"
pkgbox_is_function foobar || pkgbox_die "foobar is no function"

