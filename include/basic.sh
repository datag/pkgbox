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

# Includes functionality by sourcing a bash script
# @param string pkgbox library relative to pkgbox installation
function pkgbox_include()
{
	local file="$PKGBOX_PATH/$1"
	[[ -r $file && -f $file ]] || { pkgbox_msg error "$FUNCNAME: Include not found or not readable"; return 2; }
	
	source "$file" || { pkgbox_msg error "$FUNCNAME: Include cannot be sourced"; return 2; }
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
# @test for i in 1 12 0 -1 -12 0.0 1.0 -1.0 +3 1a a1 -a1 -1a '' ' '; do	echo "pkgbox_is_int($i) = $(pkgbox_is_int "$i" && echo yes || echo no)"; done
function pkgbox_is_int()
{
	egrep '^-?[0-9]+$' <<<$1 &>/dev/null
}

# Set SGR (Select Graphic Rendition) parameters
#
# If called without parameters it will reset SGR
#
# @param [string...] option
# @url http://en.wikipedia.org/wiki/ANSI_escape_code#graphics
# @url http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
# @FIXME: "no-color"-mode and/or terminal
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

# Echo function for text output (uses _sgr() to reset SGR afterwards)
# @param [string...] text to output
function pkgbox_echo()
{
	echo "$@$(_sgr)"	# echo and reset SGR
}

# Message function with message-type as highlighted and left-padded prefix to the message (honors verbosity level and uses pkgbox_echo())
# @param [string] type of message (debug|info|notice|warn|error|fatal)
# @param [string]... message text
# @test for i in debug info notice warn error fatal foobar '' ' '; do pkgbox_msg "$i" "pkgbox_msg($i)"; done
function pkgbox_msg()
{
	(( $# )) || { pkgbox_msg warn "$FUNCNAME: Invalid invocation: No message type given"; return 0; }  # show warning but return no error
	
	local t=${1:-'??????'} threshold=0 c=black
	shift
	
	case $t in
	"debug")  threshold=3 c=blue ;;
	"info")   threshold=2 c=green ;;
	"notice") threshold=1 c=cyan ;;
	"warn")   c=yellow ;;
	"error" | "fatal") c=red ;;
	esac
	
	(( PKGBOX_VERBOSITY >= threshold )) && \
		pkgbox_echo "$(_sgr fg=$c reverse)[$(printf '% 6s' "${t^^}")]$(_sgr) $@" || \
		true   # set function return value to 0
}

# Formats number of bytes into human friendly format, e.g. 1024 Bytes -> 1 KiB
# @param int filesize in bytes
# @test for i in $(seq 0 5); do	v=$((1024**i));	for j in $((v-1)) $((v)) $((v+1)) $((v*512)); do pkgbox_msg debug "pkgbox_byteshuman($j) = $(pkgbox_byteshuman $j)"; done; done
function pkgbox_byteshuman()
{
	awk -v x="$1" 'BEGIN { if (x<1024) { print x " Byte(s)" } else { split("KiB MiB GiB TiB PiB", t); while (x>=1024) { x/=1024; ++i }; printf("%.2f %s", x, t[i]) } }'
}

# Random string generator
# @param [int=32] number of characters
# @param [string] filter pattern
# @test for i in '' 5 0; do	for j in '' 'a-c1-3'; do echo "pkgbox_rndstr($i, '$j') = $(pkgbox_rndstr "$i" "$j")"; done; done
function pkgbox_rndstr()
{
	tr -dc "${2:-A-Za-z0-9}" </dev/urandom | head -c ${1:-32} || { \
		[[ $? == 141 ]] && return 0 || pkgbox_msg error "Cannot generate random string"; \
	}
}

