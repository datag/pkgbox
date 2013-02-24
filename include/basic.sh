# Prints usage (stdout)
function pkgbox_usage()
{
	cat <<-EOT
		Usage: ${0##*/} [OPTION]... <package-file> <action>
		       ${0##*/} [OPTION]... <package-string> <action>
		       ${0##*/} [OPTION]... -T
		       ${0##*/} [OPTION]... -h
		
		Options:
		    -v	Be verbose; Given multiple times verbosity level (default=1) increases
		    -q	Be quiet;   Given multiple times verbosity level (default=1) decreases
		    -V <version>	Override package default version
		    -D <key>[=<value>]
		        Define a setting; available settings:
		        * base     Base directory of pkgbox (default: \$HOME/.pkgbox)
		        * config   Additional config to include
		        * prefix   Install prefix (default: /usr/local)
		        * force    Force re-running action
		    -T  Run test suite
		    -h  Display this help message and exit
		
		Actions:
		    fetch, unpack, prepare, configure, compile, install,
		    info, clean
	EOT
}

# Prints message (stderr) and die
# @param string... msg
# @param [int=1] exitcode
function pkgbox_die()
{
	local exitcode=1 msg=$@ frame=0 subcall
	
	# use last argument as exit code if it is an integer
	pkgbox_is_int "${@:$#}" && msg=${@:1:$# - 1} exitcode=${@:$#}
	
	pkgbox_msg fatal "$(_sgr bold)($exitcode)$(_sgr) $msg" >&2
	
	# print stacktrace
	while subcall=$(caller $frame); do
		pkgbox_echo "  $(_sgr fg=red)>>$(_sgr) $(_sgr bold)[frame $frame]$(_sgr) $subcall" >&2
		((++frame))
	done
	
	exit $exitcode
}

# Includes functionality by sourcing a bash script
# @param string pkgbox library relative to pkgbox installation
function pkgbox_include()
{
	local file="$PKGBOX_PATH/$1"
	[[ -f $file ]] || { pkgbox_msg error "Library '$file' not found"; return 2; }
	
	source "$file" || { pkgbox_msg error "Library '$file' cannot be loaded"; return 2; }
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

# Tests whether value is an integer (may be negative)
# @param string value
# @return int non-zero if value is not an integer
function pkgbox_is_int()
{
	egrep '^-?[0-9]+$' <<<"$1" &>/dev/null
}

# Set SGR (Select Graphic Rendition) parameters
#
# If called without parameters it will reset SGR
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
			*)         m=0 ;;  # black and others
			esac
			[[ $opt == "bg" ]] && m="4${m}" || m="3${m}"
			;;
		*) m=0 ;;  # reset/normal
		esac
		
		sgr="${sgr-}${m};"
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
	local osc='\e]' m=${2:-0} text=$1 bel='\a'
	
	echo -n -e "${osc}${m};${text}${bel}"
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

# Outputs variables for debugging purpose
# @param string... Name of variable (resolved via indirection)
function pkgbox_debug_vars()
{
	local str= i
	for i in $@; do
		str="$str"$'\n'"$(_sgr fg=blue bold)$(printf "% 10s" "$i")$(_sgr) = $(_sgr underline)${!i-}$(_sgr)"
	done
	pkgbox_msg debug "Vars:$str"
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
			argstr="$argstr $(printf "'%s'" "$i")"   # printf("%q" "$i") doesn't put quotes around argument
		else
			argstr="$argstr $i"
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
	
	(( PKGBOX_VERBOSITY > 2 )) && pkgbox_msg debug "$FUNCNAME: $(_sgr bold)$cmd$(_sgr) $(pkgbox_print_quoted_args "$@")"
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

# Splits a package string into it's parts
# @param string Package string, e.g. app-misc/hello-2.8
# @param [string] Override version
# @return string Parts separated by space: "name-version name version"
function pkgbox_package_version_parts()
{
	local p=${1##*/} pn pv=${2-}	# strip dirname from package, if any
	p=${p%.pkgbox}					# strip extension, if set
	
	local regex='^(.*)(-[0-9\.]+[a-zA-Z_]*[0-9\.]*(-[a-zA-Z][0-9]+)?)$'
	if [[ $p =~ $regex ]]; then
		pn=${BASH_REMATCH[1]}
		
		if [[ ! $pv ]]; then		# version override
			pv=${BASH_REMATCH[2]}
			pv=${pv:1}				# cut off first dash
		fi
		
		p="$pn-$pv"
	else
		pn=$p
	fi
	
	if [[ $pv ]]; then
		p="$pn-$pv"
	fi
	
	echo "$p $pn $pv"
}

