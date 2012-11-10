# Download helper
function pkgbox_download()
{
	#wget --trust-server-names --content-disposition
	#curl -J -O http://www.vim.org/scripts/download_script.php?src_id=9750
	
	if pkgbox_is_command curl; then
		pkgbox_msg debug "$FUNCNAME: Using curl"
	elif pkgbox_is_command wget; then
		pkgbox_msg debug "$FUNCNAME: Using wget"
	else
		pkgbox_die "$FUNCNAME: No program for file download found" 2
	fi
}

