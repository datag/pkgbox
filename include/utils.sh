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
	*)
		pkgbox_msg error "Unknown file type: $lfile"
		return 1
		;;
	esac
}

# @TODO: support for compressed patches
function pkgPatch()
{
	local pfile=$1 ldir=${2:-$S} plevel out rc
	
	pkgbox_msg info "Applying patch $pfile"
	
	# try patch levels (patch num) from 0 to 4
	for plevel in {0..4}; do
		# If the patch fails it'll just skipped (batch mode). However, as the exit code is 1 (mild error)
		# there seems no sane way to notice a wrong patch level (patch-util not finding the patch file.
		# Solution: Set and catch the output from stdout and test if it returned non-zero length data.
		out=$(patch -d "$ldir" -i "$pfile" --silent --batch -p${plevel} -o - -r - 2>/dev/null) || rc=$?
		
		# we've got bytes, let's give it a try
		(( ${#out} )) && break;
		
		pkgbox_msg debug "#$((plevel+1)) try with patch level $plevel failed [$rc]"
	done
	
	if (( ${#out} )); then
		# -u  -N  -l --silent
		patch -d "$ldir" -i "$pfile" --batch -N -p${plevel} && rc=0 || rc=$?
		
		if (( rc > 1 )); then
			pkgbox_msg error "Error applying patch: Patch failed [$rc]"
			return $rc
		elif (( rc == 1 )); then
			pkgbox_msg warn "Patch may have failed hunks"
		else
			pkgbox_msg info "Patch successfully applied"
		fi
	else
		pkgbox_msg error "Error applying patch: Cannot determine patchlevel"
		return 1
	fi
}

function pkgbox_vcs_checkout()
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
				git checkout $v -f "$version"
				#git submodule $v init
				#git submodule $v update
			)
		else
			(
				cd "$lpath"
				#git clean $v -d -f -x
				git checkout $v -f "$version"
				git pull $v "$repo_uri" "$version"
				#git submodule $v update
			)
		fi
	elif [[ $repo_uri == *svn* ]]; then
		# Subversion repository
		
		(( PKGBOX_VERBOSITY == 0 )) && v="-q"
		
		if [[ ! -d $lpath ]]; then
			svn checkout $v "$repo_uri/$version" "$lpath"
		else
			#svn revert $v -R "$lpath"
			svn switch $v "$repo_uri/$version" "$lpath"
		fi
	else
		pkgbox_msg error "Unknown VCS repository: $repo_uri"
		return 1
	fi
}

