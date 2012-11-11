# Download helper
# @param string URI of remote file
# @param string local file name (basename)
# @param [string] output directory
# @TODO: continue download
function pkgbox_download()
{
	local rfile=$1 lname=$2 ldir=${3-${PKGBOX_DIR[download]}}
	local lfile="$ldir/$lname" cmd args errcode
	declare -a args
	
	if [[ -f "$lfile" ]]; then
		pkgbox_msg notice "Skipping download of file '${lname}' (already exists)"
		return 0
	else
		pkgbox_msg info "Downloading '$rfile'"
	fi
	
	if pkgbox_is_command curl; then
		cmd=curl
		
		if (( PKGBOX_VERBOSITY == 0 )); then
			args+=("--silent" "--show-error")
		elif (( PKGBOX_VERBOSITY < 3 )); then
			args+=("--progress-bar")
		fi
		
		args+=("--location" "--fail" "--output" "$lfile" "$rfile")
	elif pkgbox_is_command wget; then
		cmd=wget
		
		(( PKGBOX_VERBOSITY == 0 )) && args+=("-nv")
		
		# --continue -P "$ldir" [--trust-server-names|--content-disposition]
		args+=("-O" "$lfile" "$rfile")
	else
		pkgbox_msg error "$FUNCNAME: No program for file download found"
		return 2
	fi
	
	pkgbox_msg debug "$FUNCNAME: $cmd ${args[@]}" # FIXME: output quotes
	
	$cmd "${args[@]}"
	errcode=$?
	
	if [[ $errcode != 0 ]]; then
		pkgbox_msg error "Download of '$lname' failed (code:$errcode)"
		if [[ -f "$lfile" ]]; then
			pkgbox_msg notice "Removing incomplete file '${lfile}'"
			rm "$lfile" 2>/dev/null
		fi
		return 3
	fi
}

