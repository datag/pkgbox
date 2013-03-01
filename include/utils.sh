# Download helper
# @param string URI of remote file
# @param string local file name (basename) or "-" for stdout
# @param [string] output directory
# @TODO continue download
# @TODO choose tool to use from config, then detection as fallback
# @TODO trust server filename if $2 not given (or null)
function pkgbox_download()
{
	local rfile=$1 lname=$2 ldir=${3-${PKGBOX_DIR[download]}}
	local lfile="$ldir/$lname" cmd args errcode
	declare -a args
	
	if [[ $lname == "-" ]]; then  # stdout
		lfile="-"
	elif [[ -f $lfile ]]; then
		pkgbox_msg info "Skipping download of file '${lname}' (already exists)"
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
		pkgbox_msg error "No program for file download found"
		return 2
	fi
	
	pkgbox_exec "$cmd" "${args[@]}"
	errcode=$?
	
	if (( errcode )); then
		pkgbox_msg error "Download of '$lname' failed (code:$errcode)"
		if [[ -f $lfile ]]; then
			pkgbox_msg notice "Removing incomplete file '${lfile}'"
			rm "$lfile" 2>/dev/null
		fi
		return 3
	fi
}

function pkgbox_unpack()
{
	local lfile=$1 ldir=${2:-$WORKDIR}
	
	pkgbox_msg debug "Unpacking $lfile"
	
	case "${lfile##*.}" in
	"gz" | "bz2" | "xz" | "lzma")
		# is probably a compressed tar, fall through
		;&
	"tar" | "tgz" | "tbz" | "txz" | "tlzma")
		tar -xf "$lfile" -C "$ldir"
		;;
	"zip")
		unzip -qq "$lfile" -d "$ldir"
		;;
	"7z")
		pkgbox_msg error "7z not yet implemented"
		return 1
		;;
	*)
		pkgbox_msg error "Unknown file type: $lfile"
		return 1
		;;
	esac
}

function pkgbox_scm_checkout()
{
	local repo_uri=$1 version=${2-} lname=${3} ldir=${4-${PKGBOX_DIR[download]}}
	local lpath="$ldir/$lname" v=
	
	if [[ $repo_uri == *git* ]]; then
		# Git repository
		
		(( PKGBOX_VERBOSITY == 0 )) && v="-q"
		
		if [[ ! -d $lpath ]]; then
			git clone $v "$repo_uri" "$lpath"  #--depth=100
			(
				cd "$lpath"
				git checkout $v -f "$PV"
				#git submodule $v init
				#git submodule $v update
			)
		else
			(
				cd "$lpath"
				#git clean $v -d -f -x
				git checkout $v -f "$PV"
				git pull $v "$repo_uri" "$PV"
				#git submodule $v update
			)
		fi
	#elif [[ $repo_uri == *svn* ]]; then
	#elif [[ $repo_uri == *cvs* ]]; then
	else
		pkgbox_msg error "Unknown SCM repository: $repo_uri"
		return 1
	fi
}

