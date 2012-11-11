# Download helper
# @param string URI of remote file
# @param string local file name (basename)
# @param [string] output directory
# @TODO: continue download
function pkgbox_download()
{
	local rfile=$1 lname=$2 ldir=${3-${PKGBOX_DIR[download]}} verbosearg
	local lfile="$ldir/$lname"
	
	if [[ -f "$lfile" ]]; then
		pkgbox_msg notice "Skipping download of file '${lname}' (already exists)"
		return 0
	else
		pkgbox_msg info "Downloading '$rfile'"
	fi
	
	if pkgbox_is_command curly; then
		pkgbox_msg debug "$FUNCNAME: Using curl"
		
		(( PKGBOX_VERBOSITY == 0 )) && verbosearg="-s -S"
		
		# -C - -J -O  (use subshell + cd for output directory "-P")
		curl $verbosearg -o "$lfile" -L "$rfile"
	elif pkgbox_is_command wget; then
		pkgbox_msg debug "$FUNCNAME: Using wget"
		
		(( PKGBOX_VERBOSITY == 0 )) && verbosearg="-nv"
		
		# --continue -P "$ldir" [--trust-server-names|--content-disposition]
		wget $verbosearg -O "$lfile" "$rfile"
	else
		pkgbox_msg error "$FUNCNAME: No program for file download found"
		return 2
	fi
}

