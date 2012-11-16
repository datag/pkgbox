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
	
	# global variables
	FILESDIR="${pkg_canonical%/*}/files"
	P=${pkg_basename%.pkgbox}		# try to extract $P (name + version) from filename
	PN=${P%-*}
	PV=${PV:=${P##*-}}				# may be overridden by version provided via "-V" option
	if ! pkgbox_is_int ${PV:0:1}; then
		unset P PV
	else
		P=$PN-$PV						# in case filename did not contain $PV
	fi
	
	T="${PKGBOX_DIR[tmp]}/temp"
	D="${PKGBOX_DIR[tmp]}/image"
	WORKDIR="${PKGBOX_DIR[tmp]}/work"
	
	# FIXME: prepare directories somewhere else
	for i in "$T" "$D" "$WORKDIR"; do
		[[ ! -d "$i" ]] && mkdir "$i"
	done
	
	# debug: global vars
	pkgbox_debug_vars FILESDIR WORKDIR T D P PN PV
	
	# debug: remember all variables/functions
	local funcs_before=$(declare -F | cut -f3- -d' ')
	local vars_before=$(set -o posix; set)
	
	# include script
	pkgbox_msg debug "Sourcing $PKGBOX_PACKAGE"
	source "$PKGBOX_PACKAGE" || pkgbox_die "Error initializing package $PKGBOX_PACKAGE"
	
	# debug: print variables/functions declared by the package script
	pkgbox_msg debug "Vars after:"$'\n'"$(grep -vFe "$vars_before" <<<"$(set -o posix; set)" | grep -v "^vars_before=")"
	pkgbox_msg debug "Funcs after:"$'\n'"$(grep -vFe "$funcs_before" <<<"$(declare -F | cut -f3- -d' ')")"
	
	# TODO: check global variables
	
	# prepare some more global variables
	S=${S:="$WORKDIR/$P"}
	A=()
	for i in "${SRC_URI[@]}"; do
		A+=("${PKGBOX_DIR[download]}/${i##*/}")
	done
	
	# debug: global vars
	pkgbox_debug_vars P PN PV A S
	
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

function pkgver()
{
	[[ -n "$PV" ]] && return 0		# default is overridden
	
	PV=$1
	P=$PN-$PV
	
	pkgbox_msg debug "Using default version '$PV' for package '$PN'"
}

