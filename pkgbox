#!/usr/bin/env bash

set -e  #x
set -o pipefail		# http://petereisentraut.blogspot.de/2010/11/pipefail.html

# trap non-normal exit signals: 1/HUP, 2/INT, 3/QUIT, 15/TERM, ERR
# http://fvue.nl/wiki/Bash:_Error_handling
trap pkgbox_trap 1 2 3 15 ERR
function pkgbox_trap()
{
	pkgbox_die "TRAP" ${10:-$?}
}

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
	local exitcode=1 msg="$@"
	
	# use last argument as exit code if it is an integer
	pkgbox_is_int "${@:$#}" && msg="${@:1:$# - 1}" exitcode="${@:$#}"
	
	echo "[pkgbox die] ($exitcode) $msg" >&2
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
# @param string function name
# @return int non-zero if function does not exist
function pkgbox_is_function()
{
	declare -F "$1" >/dev/null
}

# tests if value is an integer (may be negative)
# @param string value
# @return int non-zero if value is not an integer
function pkgbox_is_int()
{
	echo $1 | egrep '^-?[0-9]+$' >/dev/null
}

################################################################################

# check for valid invocation
if [[ $# < 1 ]]; then
	pkgbox_usage >&2
	exit 1
fi

# include basic libs
pkgbox_include "include/basic.sh"

#pkgbox_is_function pkgbox_usage || pkgbox_die "pkgbox_usage is no function"
#pkgbox_is_function foobar || pkgbox_die "foobar is no function"

#false
#true

