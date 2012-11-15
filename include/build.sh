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
	
	DISTDIR=${PKGBOX_DIR[download]}
	FILESDIR="${pkg_canonical%/*}/files"
	
	P=${pkg_basename%.pkgbox}
	PN=${P%-*}
	PV=${P##*-}
	WORKDIR="${PKGBOX_DIR[tmp]}/work"
	S="$WORKDIR/$P"
	T="${PKGBOX_DIR[tmp]}/temp"
	D="${PKGBOX_DIR[tmp]}/image"
	
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
	
	# declare default functions
	if ! pkgbox_is_function "src_unpack"; then
		pkgbox_msg debug "Defining default src_unpack()"
		
		function src_unpack()
		{
			pkgbox_msg debug "Default src_unpack()"
			#if [[ -n "${A}" ]]; then
			#	pkgbox_unpack ${A}
			#fi
		}
	fi
}

function pkgbox_action_unpack()
{
	src_unpack
}

function pkgbox_action_fetch()
{
	pkgbox_msg debug TODO: fetch
}

