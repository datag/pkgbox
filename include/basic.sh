
function pkgbox_echo()
{
	local magic=':' esc='\e[' term='m' arg color
	
	# http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
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
	
	for arg in "$@"; do
		color="${arg:1:${#arg}-2}"  # the construct "${arg:1:-1}" is bash >= 4.2
		
		if [[ ${colors[$color]} ]]; then
			echo -n -e ${esc}${colors[$color]}${term}
		else
			echo -n "$arg"
		fi
	done
	
	echo -e ${esc}${colors[reset]}${term} # reset and linebreak
}

