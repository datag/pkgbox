# Prints usage (stdout)
function pkgbox_usage()
{
	pkgbox_echo "Usage: ${0##*/} [OPTION]... <ACTION> <PKGFILE>"
}

# Prints message (stderr) and die
# @param string... msg
# @param [int=1] exitcode
function pkgbox_die()
{
	local exitcode=1 msg="$@"
	
	# use last argument as exit code if it is an integer
	pkgbox_is_int "${@:$#}" && msg="${@:1:$# - 1}" exitcode="${@:$#}"
	
	pkgbox_msg fatal "$(_sgr bold)($exitcode)$(_sgr) $msg" >&2
	exit $exitcode
}

# Includes functionality
function pkgbox_include()
{
	local file="$PKGBOX_PATH/$1"
	[[ -r $file && -f $file ]] || pkgbox_die "$FUNCNAME: Include file '$1' not found" 2
	
	source "$file"
}

# Tests whether function exists
# @param string function name
# @return int non-zero if function does not exist
function pkgbox_is_function()
{
	declare -F "$1" &>/dev/null
}

# Tests whether a command is available
# @param string command name
# @return int non-zero if command does not exist
function pkgbox_is_command()
{
	type -P "$1" &>/dev/null
}

# Tests whether value is an integer (may be negative)
# @param string value
# @return int non-zero if value is not an integer
function pkgbox_is_int()
{
	echo $1 | egrep '^-?[0-9]+$' &>/dev/null
}

# Set SGR (Select Graphic Rendition) parameters
#
# If called without parameters it will reset SGR
#
# @param [string...] Option
# @url http://en.wikipedia.org/wiki/ANSI_escape_code#graphics
# @url http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
function _sgr()
{
	local csi='\e[' term='m' arg sgr opt m
	
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
		
		sgr="${sgr}${m};"
	done
	
	[[ -z "$sgr" ]] && sgr="0" || sgr="${sgr:0:${#sgr}-1}"	# remove superfluous trailing ";"
	
	echo -n -e "${csi}${sgr}${term}"
}

# Echo function using _sgr() to reset SGR afterwards
function pkgbox_echo()
{
	echo "$@$(_sgr)"	# echo and reset SGR
}

# Message function using pkg_echo
function pkgbox_msg()
{
	local t=$1 threshold=0 c=black
	shift
	
	case $t in
	"debug")  threshold=3; c=blue ;;
	"info")   threshold=2; c=green ;;
	"notice") threshold=1; c=cyan ;;
	"warn")   c=yellow ;;
	"error" | "fatal") c=red ;;
	esac
	
	(( PKGBOX_VERBOSITY >= threshold )) && \
		pkgbox_echo "$(_sgr fg=$c reverse)[$(printf '% 6s' "${t^^}")]$(_sgr) $@" || \
		true
}

