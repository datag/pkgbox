################################################################################
# pkgbox - The build toolbox
# 
# Core library - basic functionality
# 
# Copyright 2012, 2013  Dominik D. Geyer <dominik.geyer@gmail.com>
# License: GPLv3 (see file LICENSE)
################################################################################

# Prints usage message
function pkgbox_usage()
{
	cat <<-EOT
		Usage: ${0##*/} [OPTION]... <package-file> [<action>]
		       ${0##*/} [OPTION]... <package-string> [<action>]
		       ${0##*/} [OPTION]... -T
		       ${0##*/} [OPTION]... -h
		
		Options:
		    -v	Be verbose; Given multiple times verbosity level (default=1) increases
		    -q	Be quiet;   Given multiple times verbosity level (default=1) decreases
		    -V <version>	Override package default version
		    -D <key>[=<value>]
		        Define a setting. Available settings:
		        * config     Additional configuration file to include
		        * base       User directory of pkgbox (default: \$HOME/.pkgbox)
		        * packages   Packages directory (default: {pkgbox-root}/pkg)
		        * download   Directory for downloaded files (default: {base}/download)
		        * build      Build directory (default: {base}/build)
		        * prefix     Install prefix (default: /usr/local)
		        * CFLAGS CXXFLAGS CPPFLAGS LDFLAGS EXTRA_LDFLAGS_PROGRAM LIBS CC CXX
		                     Options for Configure (pkgConfigure helper)
		        * make_opts  Options for Make (pkgMake helper)
		        * force      If set, force re-running action
		    -F <feature>[=value]
		        Enable/disable/set a package feature. Possible values are "y", "n" or
		        an (empty) string. If value is omitted, the value "y" is set.
		    -T  Run test suite
		    -h  Display this help message and exit
		
		Actions (default: info):
		    fetch, unpack, prepare, configure, compile, install,
		    info, clean
		
		An environment variable PKGBOX_INCLUDE can be set for pkgbox to find its core
		library. The default is the canonicalized path of this script plus "/include".
	EOT
}

# Trap handler for signals HUP, INT, QUIT, TERM, ERR and EXIT.
# @param int     Return code of last command
# @param string  Last command
# @param string  Source file
# @param int     Source line number
# @calls pkgbox_exit($rc)
# @see http://wiki.bash-hackers.org/commands/builtin/caller
function pkgbox_trap_handler()
{
	local rc=$1 cmd=$2 srcfile=$3 srcline=$4
	local msg="${srcfile##*/}@${srcline}: $(_sgr underline)${cmd}$(_sgr)"
	
	pkgbox_msg fatal "$(echo >&2)$(_sgr fg=red bold)(TRAP: $rc)$(_sgr) $msg" >&2
	pkgbox_stacktrace 1

	pkgbox_exit $rc
}

# Prints message (stderr) and die
# @param string... msg
# @param [int=1] exitcode
# @calls pkgbox_exit($rc)
function pkgbox_die()
{
	local exitcode=1 msg=$@
	
	# use last argument as exit code if it is an integer
	pkgbox_is_int "${@:$#}" && msg=${@:1:$# - 1} exitcode=${@:$#}
	
	pkgbox_msg fatal "$(_sgr fg=red bold)(DIE: $exitcode)$(_sgr) $msg" >&2
	pkgbox_stacktrace 1
	
	pkgbox_exit $exitcode
}

# Prints the current execution call stack, a stacktrace
# @param [int=0] Frame to start
function pkgbox_stacktrace()
{
	local frame=${1-0} subcall sc_l sc_s sc_f sc_str
	
	# print stacktrace
	while subcall=$(caller $frame); do
		read sc_l sc_s sc_f <<<"$subcall"
		sc_str=$(printf "%03d  % 25s  % 30s" "$sc_l" "$sc_s" "${sc_f/#$PKGBOX_PATH/(BASEDIR)}")
		pkgbox_echo "  $(_sgr fg=red)>>$(_sgr) $(_sgr bold)[frame $frame]$(_sgr) $sc_str" >&2
		
		((++frame))
	done
}

# Removes all traps and exits with given exit code
# @param int Exit code
# @exit
function pkgbox_exit()
{
	# remove all traps
	trap - HUP INT QUIT TERM ERR EXIT

	# exit with error
	exit ${1-0}
}

# Includes functionality by sourcing a bash script
# @param string pkgbox library relative to pkgbox installation
function pkgbox_include()
{
	local file="$PKGBOX_INCLUDE/${1}.sh"
	[[ -f $file ]] || { pkgbox_msg error "Library '$file' not found."; return 2; }
	
	source "$file" || { pkgbox_msg error "Library '$file' cannot be loaded."; return 2; }
}

# Tests whether function exists
# @param string function name
# @return int non-zero if function does not exist
function pkgbox_is_function()
{
	declare -F "$1" &>/dev/null
}

# Tests whether a command is available (tests for shell-builtin, function or alias, too)
# @param string command name
# @return int non-zero if command does not exist
function pkgbox_is_command()
{
	type -p "$1" &>/dev/null	# -P
}

# Tests whether variable name is defined as an indexed or associative array
# @param string name of variable
# @return int non-zero if variable is not an array
# @see http://fvue.nl/wiki/Bash:_Detect_if_variable_is_an_array
function pkgbox_is_array()
{
	declare -p "$1" 2>/dev/null | grep -q '^declare -[aA]'
}

# Tests whether value is an integer (may be negative)
# @param string value
# @return int non-zero if value is not an integer
function pkgbox_is_int()
{
	egrep '^-?[0-9]+$' <<<"$1" &>/dev/null
}

# Set SGR (Select Graphic Rendition) parameters
#
# If called without or with unknown parameters SGR will be reset.
#
# @param [string...] option
# @see http://en.wikipedia.org/wiki/ANSI_escape_code#graphics
# @see http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
# @FIXME: "no-color"-mode and/or terminal
function _sgr()
{
	local csi='\e[' term='m' arg sgr= opt m
	
	for arg in $*; do
		opt=${arg%%=*}
		case $opt in
		"bold" | "bright")      m=1 ;;
		"underline")            m=4 ;;
		"blink")                m=5 ;;
		"reverse" | "inverse")  m=7 ;;
		"fg" | "c" | "bg")
			case ${arg#*=} in
			"red")     m=1 ;;
			"green")   m=2 ;;
			"yellow")  m=3 ;;
			"blue")    m=4 ;;
			"magenta") m=5 ;;
			"cyan")    m=6 ;;
			"white")   m=7 ;;
			*)         m=0 ;;  # black (and unknown)
			esac
			[[ $opt == "bg" ]] && m="4${m}" || m="3${m}"
			;;
		*) m=0 ;;  # reset/normal (and unknown)
		esac
		
		sgr+="${m};"
	done
	
	[[ ! ${sgr} ]] && sgr="0" || sgr=${sgr%;}	# remove superfluous trailing ";"
	
	echo -n -e "${csi}${sgr}${term}"
}

# Sets the icon name and/or window title of the terminal emulator (xterm and similar)
#
# @param string Text to set as icon name and/or window title
# @param [int=0*|1|2] What to set:
# 			0: Icon name and window title (default)
# 			1: Icon name only
# 			2: Window title only
# @see http://www.faqs.org/docs/Linux-mini/Xterm-Title.html#s3
# @see http://en.wikipedia.org/wiki/ANSI_escape_code#Non-CSI_codes
function pkgbox_title()
{
	# only set icon name / window title if stderr is a tty
	[[ -t 2 ]] || return 0
	
	# check for compatible terminal
	case $TERM in
	*term | xterm-color | rxvt | vt100 | gnome* )
		local osc='\e]' m=${2:-0} text=$1 bel='\a'
		echo -n -e "${osc}${m};${text}${bel}" >&2
		;;
	*)	# unknown terminal, better don't mess with it
		;;
	esac
}

# Echo function for text output (uses _sgr() to reset SGR afterwards)
# @param [string...] text to output
function pkgbox_echo()
{
	echo "$@$(_sgr)"	# echo and reset SGR
}

# Message function with message-type as highlighted and left-padded prefix to the message (honors verbosity level and uses pkgbox_echo())
# @param [string] type of message (debug|info|notice|warn|error|fatal)
# @param [string]... message text
function pkgbox_msg()
{
	local t=${1:-'??????'} threshold=0 c="black"
	shift
	
	case $t in
	"debug")  threshold=3 c="blue" ;;
	"info")   threshold=2 c="green" ;;
	"notice") threshold=1 c="cyan" ;;
	"warn")               c="yellow" ;;
	"error" | "fatal")    c="red" ;;
	esac
	
	(( PKGBOX_VERBOSITY >= threshold )) && \
		pkgbox_echo "$(_sgr fg=$c reverse)[$(printf '% 6s' "${t^^}")]$(_sgr) $@" >&2 || \
		true	# success exit code so this function always returns success, too
}

# Outputs variables/arrays/functions for debugging purpose
# @param string... Name of variable (resolved via indirection or eval)
# @FIXME: Can eval be avoided for printing array?
function pkgbox_debug_vars()
{
	(( PKGBOX_VERBOSITY < 3 )) && return 0	# return early
	
	local str= var key ivar val func
	for var in "$@"; do
		if pkgbox_is_array "$var"; then
			str+=$'\n'"$(_sgr fg=blue bold)$(printf "% 10s" "$var")$(_sgr) ="
			
			while read -r key; do
				ivar="\${$var['$key']}"
				val=$(eval "echo -n \"$ivar\"")
				str+=$'\n'"$(_sgr fg=green bold)$(printf "% 14s" "[$key]")$(_sgr) = $(_sgr underline)${val}$(_sgr)"
			done < <(eval 'for i in "${!'$var'[@]}"; do echo "$i"; done')
		elif pkgbox_is_function "$var"; then
			func=$(declare -f "$var")
			str+=$'\n'"$(_sgr fg=red bold)$(printf "% 10s" "$var()")$(_sgr) = ${func#"$var ()"}"
		else
			str+=$'\n'"$(_sgr fg=blue bold)$(printf "% 10s" "$var")$(_sgr) = $(_sgr underline)${!var-}$(_sgr)"
		fi
	done
	pkgbox_msg debug "Vars:$str"
}

# debug output declared variables against previously saved state
# e.g. save state:  local vars_before=$(set -o posix; set)
function pkgbox_debug_declared_vars()
{
	local out=$(grep -vFe "${!1}" <<<"$(set -o posix; set)" | egrep -v "^(${1}|BASH_(LINENO|SOURCE)|FUNCNAME)=")
	pkgbox_msg debug "${2:-"Declared variables"}:"$'\n'"$(_sgr fg=black bg=white)$out$(_sgr)"
}

# debug output declared functions against previously saved state
# e.g. save state:  local funcs_before=$(declare -F | cut -f3- -d' ')
function pkgbox_debug_declared_funcs()
{
	local out=$(grep -vFe "${!1}" <<<"$(declare -F | cut -f3- -d' ')" || :)
	pkgbox_msg debug "${2:-"Declared functions"}:"$'\n'"$(_sgr fg=black bg=white)$out$(_sgr)"
}

# Formats number of bytes into human friendly format, e.g. 1024 Bytes -> 1 KiB
# @param int filesize in bytes
function pkgbox_byteshuman()
{
	local x=${1:-0}
	pkgbox_is_int "$x" || return 2 && ((x >= 0)) || return 2
	awk -v x="$x" 'BEGIN { if (x<1024) { printf("%d Byte(s)", x) } else { split("KiB MiB GiB TiB PiB", t); while (x>=1024) { x/=1024; ++i }; printf("%.2f %s", x, t[i]) } }'
}

# Random string generator
# @param [int=32] number of characters
# @param [string=alphanum] filter pattern
function pkgbox_rndstr()
{
	tr -dc "${2:-A-Za-z0-9}" </dev/urandom | head -c "${1:-32}" 2>/dev/null
	if [[ $? != 0 && $? != 141 ]]; then		# assume closed pipe (code 141) is ok
		pkgbox_msg error "Cannot generate random string"
		return 2
	fi
}

# Print arguments quoted (for echo output only!)
# @param string... arguments
# @see http://wiki.bash-hackers.org/syntax/quoting
# @see http://stackoverflow.com/questions/12985178/bash-quoted-array-expansion
function pkgbox_print_quoted_args()
{
	local i arg argstr=
	for i in "$@"; do
		if [[ $i =~ \  ]]; then
			i=${i/\'/\'\\\'\'}
			argstr+=" $(printf "'%s'" "$i")"   # printf("%q" "$i") doesn't put quotes around argument
		else
			argstr+=" $i"
		fi
	done
	
	echo -n "${argstr# }"    # echo with first white-space removed
}

# Executes a command
# @param string Command
# @param [string]... Arguments to command
# @return int Exit code of command executed
function pkgbox_exec()
{
	local cmd=$1
	shift
	
	if (( PKGBOX_VERBOSITY > 1 )); then
		pkgbox_msg info "Executing: $(_sgr bold underline)$cmd$(_sgr reset underline) $(pkgbox_print_quoted_args "$@")$(_sgr)"
	fi
	
	$cmd "$@"
}

# Trims a string (remove leading and trailing white-spaces)
# @param string String to trim
# @see http://stackoverflow.com/a/6282142/984787  (unused: approach using bash regex matching)
# @see http://stackoverflow.com/a/8999678/984787  (unused: approach using read)
function pkgbox_trim()
{
	if [[ $1 =~ [[:space:]]*([^[:space:]]|[^[:space:]].*[^[:space:]])[[:space:]]* ]]; then
		echo -n "${BASH_REMATCH[1]}"
	else
		echo -n "$1"
	fi
}

