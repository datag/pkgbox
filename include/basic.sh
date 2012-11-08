# http://en.wikipedia.org/wiki/ANSI_escape_code#graphics
# http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
function pkgbox_echo()
{
	local magic=':' csi='\e[' term='m' arg color
	
	declare -A colors=( \
		[black]="0;30" [bright_black]="1;30" \
		[red]="0;31"  [bright_red]="1;31" \
		[green]="0;32" [bright_green]="1;32" \
		[yellow]="0;33"  [bright_yellow]="1;33" \
		[blue]="0;34" [bright_blue]="1;34" \
		[cyan]="0;36" [bright_cyan]="1;36" \
		[magenta]="0;35" [bright_magenta]="1;35" \
		[white]="0;37" [bright_white]="1;37" \
		[reset]="0" \
	)
	
	declare i=0
	
	for arg in "$@"; do
		color="${arg:1:${#arg}-2}"  # NOTE: the construct "${arg:1:-1}" is bash >= 4.2
		
		if [[ $arg == ${magic}*${magic} && ${#color} > 0 && ${colors[$color]} ]]; then
			echo -n -e ${csi}${colors[$color]}${term}
		else
			(( i++ > 0  )) && echo -n " "
			echo -n "$arg"
		fi
	done
	
	echo -e ${csi}${colors[reset]}${term}  # reset SGR and break line
}

