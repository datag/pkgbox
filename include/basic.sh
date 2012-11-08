# http://en.wikipedia.org/wiki/ANSI_escape_code#graphics
# http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
function pkgbox_sgr()
{
	local csi='\e[' term='m' arg sgr opt m c
	
	for arg in $*; do
		opt=${arg%%=*}
		case $opt in
		"bold")      m=1 ;;
		"underline") m=4 ;;
		"blink")     m=5 ;;
		"reverse")   m=7 ;;
		"fg" | "bg")
			[[ $opt == "fg" ]] && m=3 || m=4
			case ${arg#*=} in
			"red")     c=1 ;;
			"green")   c=2 ;;
			"yellow")  c=3 ;;
			"blue")    c=4 ;;
			"magenta") c=5 ;;
			"cyan")    c=6 ;;
			"white")   c=7 ;;
			*)         c=0;  # black and others
			esac
			m="${m}${c}"
			;;
		*) m=0 ;;  # reset/normal
		esac
		
		sgr="${sgr}${m};"
	done
	
	[[ -z "$sgr" ]] && sgr="0" || sgr="${sgr:0:${#sgr}-1}"	# remove trailing ";"
		
	#echo -n " { ${csi}${sgr}${term}] }"	#debug
	echo -n -e "${csi}${sgr}${term}"
}

function pkgbox_echo()
{
	echo "$@$(pkgbox_sgr)"	# echo and reset SGR
}

