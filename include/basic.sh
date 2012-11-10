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

