function pkgbox_action()
{
	local action=$1 i n curaction
	declare -a actions
	
	case $1 in
	"unpack")
		actions+=("unpack")
		;&
	"fetch")
		actions+=("fetch")
		;;
	*)
		pkgbox_die "Unknown action $action"
		;;
	esac
	
	actions+=("init")
	
	n=${#actions[@]}
	for (( i = n - 1; i >= 0; --i )); do
		curaction=${actions[$i]}
		pkgbox_msg debug "Action #$((n - i)): $curaction"
		
		pkgbox_action_$curaction
	done
}

function pkgbox_action_init()
{
	# imitate ebuild variables: http://devmanual.gentoo.org/ebuild-writing/variables/index.html
	local pkg_canonical=$(readlink -f $PKGBOX_PACKAGE) pkg_basename=${PKGBOX_PACKAGE##*/} i
	
	FILESDIR="${pkg_canonical%/*}/files"
	P=${pkg_basename%.pkgbox}
	PN=${P%-*}
	PV=${P##*-}
	T="${PKGBOX_DIR[tmp]}/temp"
	D="${PKGBOX_DIR[tmp]}/image"
	WORKDIR="${PKGBOX_DIR[tmp]}/work"
	S="$WORKDIR/$P"
	
	for i in "$T" "$D" "$WORKDIR"; do
		[[ ! -d "$i" ]] && mkdir "$i"
	done
	
	# debug: output all global vars
	for i in DISTDIR FILESDIR P PN PV WORKDIR S T D; do
		pkgbox_msg debug "$i='${!i}'"
	done
	
	# debug: remember all variables/functions
	local funcs_before=$(declare -F | cut -f3- -d' ')
	local vars_before=$(set -o posix; set)
	
	# include script
	pkgbox_msg debug "Sourcing $PKGBOX_PACKAGE"
	source "$PKGBOX_PACKAGE" || pkgbox_die "Error initializing package $PKGBOX_PACKAGE"
	
	# debug: print variables/functions declared by the package script
	pkgbox_msg debug "Vars after:"$'\n'"$(grep -vFe "$vars_before" <<<"$(set -o posix; set)" | grep -v "^vars_before=")"
	pkgbox_msg debug "Funcs after:"$'\n'"$(grep -vFe "$funcs_before" <<<"$(declare -F | cut -f3- -d' ')")"
	
	# prepare some more environment variables
	A=()
	for i in "${SRC_URI[@]}"; do
		A+=("${PKGBOX_DIR[download]}/${i##*/}")
	done
	
	# declare default functions
	if ! pkgbox_is_function "src_fetch"; then
		pkgbox_msg debug "Defining default src_fetch()"
		
		function src_fetch()
		{
			pkgbox_msg debug "Default src_fetch()"
			pkgbox_download "$SRC_URI" "${SRC_URI##*/}"
		}
	fi	
	
	if ! pkgbox_is_function "src_unpack"; then
		pkgbox_msg debug "Defining default src_unpack()"
		
		function src_unpack()
		{
			local filename
			pkgbox_msg debug "Default src_unpack()"
			
			for filename in "${A[@]}"; do
				pkgbox_unpack "$filename"
			done
		}
	fi
}

function pkgbox_action_fetch()
{
	local uri
	
	pkgbox_msg info "src_fetch()"
	
	for uri in "${SRC_URI[@]}"; do
		pkgbox_download "$uri" "${uri##*/}"
	done
}

function pkgbox_action_unpack()
{
	pkgbox_msg info "src_unpack()"
	
	if [[ -d "$S" ]]; then
		pkgbox_msg info "Skipping unpacking file (directory already exists)"
		return 0
	fi
	
	src_unpack
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
}

