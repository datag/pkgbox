function pkgbox_action()
{
	local action=$1 i n curaction outdesc
	declare -a actions
	
	(( PKGBOX_VERBOSITY < 2 )) && outdesc=/dev/null || outdesc=/dev/stdout
	
	case $action in
	"info")
		actions+=("info")
		;;
	"clean")
		actions+=("clean")
		;;
	"install")
		actions+=("install")
		;&
	"compile")
		actions+=("compile")
		;&
	"configure")
		actions+=("configure")
		;&
	"prepare")
		actions+=("prepare")
		;&
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
	
	# always needed
	pkgbox_action_init >$outdesc
	
	n=${#actions[@]}
	for (( i = n - 1; i >= 0; --i )); do
		curaction=${actions[$i]}
		pkgbox_msg notice "Action #$((n - i)): $curaction"
		
		# already done?
		if [[ -f "$S/.pkgbox_$curaction" ]]; then
			if [[ $curaction == $action && -n "${PKGBOX_OPTS[force]}" ]]; then
				pkgbox_msg info "Action '$curaction' forced"
			else
				pkgbox_msg info "Action '$curaction' already completed, skipping..."
				continue
			fi
		fi
		
		pkgbox_action_$curaction >$outdesc
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
	INSTALLDIR=${PKGBOX_OPTS[prefix]}
	
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
	pkgbox_msg debug "Funcs after:"$'\n'"$(grep -vFe "$funcs_before" <<<"$(declare -F | cut -f3- -d' ')" || true)"
	
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
	
	if ! pkgbox_is_function "src_prepare"; then
		pkgbox_msg debug "Defining default src_prepare()"
		
		function src_prepare()
		{
			pkgbox_msg debug "Default src_prepare()"
		}
	fi
	
	if ! pkgbox_is_function "src_configure"; then
		pkgbox_msg debug "Defining default src_configure()"
		
		function src_configure()
		{
			pkgbox_msg debug "Default src_configure()"
			
			pkgConfigure
		}
	fi
	
	if ! pkgbox_is_function "src_compile"; then
		pkgbox_msg debug "Defining default src_compile()"
		
		function src_compile()
		{
			pkgbox_msg debug "Default src_compile()"
			
			pkgMake
		}
	fi
	
	if ! pkgbox_is_function "src_install"; then
		pkgbox_msg debug "Defining default src_install()"
		
		function src_install()
		{
			pkgbox_msg debug "Default src_install()"
			
			pkgMake install
		}
	fi
}

function pkgbox_action_fetch()
{
	local uri filename
	
	pkgbox_msg info "src_fetch()"
	
	for uri in "${SRC_URI[@]}"; do
		filename=${uri##*/}
		pkgbox_download "$uri" "$filename"
		
		# check naively for invalid download (e.g. HTML instead of 404)
		if head -c 100 "${PKGBOX_DIR[download]}/$filename" | grep -i '<html' &>/dev/null; then
			pkgbox_msg warn "Downloaded file '$filename' seems to be invalid (is HTML)"
			#return 1
		fi
	done
}

function pkgbox_action_unpack()
{
	pkgbox_msg info "src_unpack()"
	
	src_unpack
	touch "$S/.pkgbox_unpack"
}

function pkgbox_action_prepare()
{
	pkgbox_msg info "src_prepare()"
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
	
	src_prepare
	touch "$S/.pkgbox_prepare"
}

function pkgbox_action_configure()
{
	pkgbox_msg info "src_configure()"
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
	
	src_configure
	touch "$S/.pkgbox_configure"
}

function pkgbox_action_compile()
{
	pkgbox_msg info "src_compile()"
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
	
	src_compile
	touch "$S/.pkgbox_compile"
}

function pkgbox_action_install()
{
	pkgbox_msg info "src_install()"
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
	
	[[ ! -d "$INSTALLDIR" ]] && mkdir -p "$INSTALLDIR"
	src_install
	touch "$S/.pkgbox_install"
}

function pkgbox_action_clean()
{
	local filename
	
	pkgbox_msg info "clean()"
	
	pkgbox_msg notice "Removing '$PN' working directory"
	[[ "${S:0:${#WORKDIR}}" == "$WORKDIR" ]] || pkgbox_die "Invalid working directory '$S'"
	rm -rf "$S" &>/dev/null
	
	for filename in "${A[@]}"; do
		pkgbox_msg notice "Removing '$PN' download file"
		rm -f "$filename" &>/dev/null
	done
}

function pkgbox_action_info()
{
	pkgbox_msg info "info()"
	
}

function pkgVer()
{
	[[ -n "$PV" ]] && return 0		# default is overridden
	
	PV=$1
	P=$PN-$PV
	
	pkgbox_msg debug "Using default version '$PV' for package '$PN'"
}

function pkgConfigure()
{
	pkgbox_exec \
		./configure \
			CFLAGS="${PKGBOX_OPTS[cflags]}" \
			CXXFLAGS="${PKGBOX_OPTS[cxxflags]}" \
			CPPFLAGS="${PKGBOX_OPTS[cppflags]}" \
			LDFLAGS="${PKGBOX_OPTS[ldflags]}" \
			--prefix="$INSTALLDIR" \
			"$@"
}

function pkgMake()
{
	local target=$1
	shift || true
	
	pkgbox_exec \
		make ${PKGBOX_OPTS[make_opts]} "$@" $target
}

