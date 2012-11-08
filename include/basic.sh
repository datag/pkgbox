# http://en.wikipedia.org/wiki/ANSI_escape_code#graphics
# http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
function pkgbox_echo()
{
	local magic=':' csi='\e[' term='m' arg color
	
	declare -A colors=( \
		[black]=0  [red]=1   [green]=2    [yellow]=3 \
		[blue]=4   [cyan]=6  [magenta]=5  [white]=7  \
	)
	
	declare i=0
	
	for arg in "$@"; do
		color="${arg:1:${#arg}-2}"  # NOTE: the construct "${arg:1:-1}" ony works in bash >= 4.2
		
		if [[ $arg == ${magic}*${magic} && ${#color} > 0 && ${colors[$color]} ]]; then
			echo -n -e ${csi}"0;3"${colors[$color]}${term}
		else
			(( i++ > 0  )) && echo -n " "
			echo -n "$arg"
		fi
	done
	
	echo -e ${csi}0${term}  # reset SGR and break line
}

