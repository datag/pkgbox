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
		
		pkgbox_title "$P <#$((n - i)) $curaction> - pkgbox"
		pkgbox_msg debug "Action #$((n - i)) $curaction"
		
		# already done?
		if [[ -f "$S/.pkgbox_$curaction" ]]; then
			if [[ $curaction == $action && ${PKGBOX_OPTS[force]-} ]]; then
				pkgbox_msg info "Action '$curaction' forced"
			else
				pkgbox_msg info "Action '$curaction' already completed, skipping..."
				continue
			fi
		fi
		
		pkgbox_action_$curaction >$outdesc
	done
}

# Variable naming are somewhat borrowed from Portage ebuild (http://devmanual.gentoo.org/ebuild-writing/variables/index.html)
function pkgbox_action_init()
{
	local pkg_file i
	
	# find package file
	pkg_file=$(pkgbox_find_package "$PKGBOX_PACKAGE" "${PV-}") || pkgbox_die "Package file for $PKGBOX_PACKAGE not found"
	
	# determine package string, name and version
	read P PN PV <<<"$(pkgbox_package_version_parts "$PKGBOX_PACKAGE" "${PV-}")"
	
	# If no package version override provided, leave package and version string
	# empty for later assignment via pkgVer and/or manual assignment in package.
	if [[ ! $PV ]]; then
		unset P PV
	fi
	
	
	# globals
	T="${PKGBOX_DIR[tmp]}/temp"
	WORKDIR="${PKGBOX_DIR[tmp]}/work"
	INSTALLDIR=${PKGBOX_OPTS[prefix]}
	FILESDIR="${pkg_file%/*}/files"
	SRC_URI=()
	
	
	# FIXME: prepare directories somewhere else
	for i in "$T" "$WORKDIR"; do
		[[ ! -d $i ]] && mkdir "$i"
	done
	
	
	# debug: global vars
	pkgbox_debug_vars FILESDIR WORKDIR T P PN PV
	
	# debug: remember all variables/functions
	local funcs_before=$(declare -F | cut -f3- -d' ')
	local vars_before=$(set -o posix; set)
	
	# include script
	pkgbox_msg debug "Sourcing $pkg_file"
	source "$pkg_file" || pkgbox_die "Error initializing package $PKGBOX_PACKAGE"
	
	# debug: print variables/functions declared by the package script
	pkgbox_msg debug "Vars after:"$'\n'"$(grep -vFe "$vars_before" <<<"$(set -o posix; set)" | grep -v "^vars_before=")"
	pkgbox_msg debug "Funcs after:"$'\n'"$(grep -vFe "$funcs_before" <<<"$(declare -F | cut -f3- -d' ')" || true)"
	
	
	# set source directory, if not set by package
	: ${S:="$WORKDIR/$P"}
	
	# determine list of files by URIs
	A=()
	for i in "${SRC_URI[@]}"; do
		A+=("${PKGBOX_DIR[download]}/${i##*/}")
	done
	
	
	# debug: global vars
	pkgbox_debug_vars P PN PV S SRC_URI A
	
	# declare default functions
	if ! pkgbox_is_function "src_fetch"; then
		pkgbox_msg debug "Defining default src_fetch()"
		
		function src_fetch()
		{
			local uri filename
			pkgbox_msg debug "Default src_fetch()"
			
			for uri in "${SRC_URI[@]}"; do
				filename=${uri##*/}
				pkgbox_download "$uri" "$filename"
			done
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

function pkgbox_find_package()
{
	local p=$1 f
	
	if [[ -f $p ]]; then
		# provided package name is already an existing file
		f=$p
	else
		# no explicit pkgbox-file given? try some default paths...
		local category=${p%/*} pv=${2-} l_p l_pn l_pv found=0
		
		read l_p l_pn l_pv <<<"$(pkgbox_package_version_parts "$p" "$pv")"
	
		declare -a locations=(
			"${PKGBOX_DIR[packages]}/${category}/${l_pn}/${l_p}.pkgbox"
			"${PKGBOX_DIR[packages]}/${category}/${l_pn}/${l_pn}.pkgbox"
			"${PKGBOX_DIR[packages]}/${l_pn}/${l_p}.pkgbox"
			"${PKGBOX_DIR[packages]}/${l_pn}/${l_pn}.pkgbox"
			"${PKGBOX_DIR[packages]}/${l_p}.pkgbox"
			"${PKGBOX_DIR[packages]}/${l_pn}.pkgbox"
		)
	
		for f in "${locations[@]}"; do
			pkgbox_msg debug "Looking for package at $f"
			if [[ -f $f ]]; then
				found=1
				break
			fi
		done
		
		if (( ! found )); then
			return 1
		fi
	fi
	
	readlink -e "$f"
}

function pkgbox_action_fetch()
{
	pkgbox_msg info "src_fetch()"
	
	src_fetch
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
	
	[[ ! -d $INSTALLDIR ]] && mkdir -p "$INSTALLDIR"
	src_install
	touch "$S/.pkgbox_install"
}

function pkgbox_action_clean()
{
	local filename
	
	pkgbox_msg info "clean()"
	
	pkgbox_msg notice "Removing '$PN' working directory"
	[[ ${S:0:${#WORKDIR}} == $WORKDIR ]] || pkgbox_die "Invalid working directory '$S'"
	rm -rf "$S" &>/dev/null
}

function pkgbox_action_info()
{
	local str=$(cat <<-EOT
		pkgbox package $(_sgr bold)${P}$(_sgr)  (API version: $PKGBOX_API)
		
		    Package:     $(_sgr bold)${PN}$(_sgr)
		    Version:     $(_sgr bold)${PV}$(_sgr)
		    Description: ${DESCRIPTION:-"n/a"}
		    Homepage:    ${HOMEPAGE:-"n/a"}
		    Source URIs: ${SRC_URI[@]:-"n/a"}
	EOT
	)
	
	pkgbox_echo "$str" >&2
}

function pkgVer()
{
	local str="Using default version"
	
	if [[ ${PV-} ]]; then
		str="Using version override"
	else
		PV=$1
		P="$PN-$PV"
	fi
	
	pkgbox_msg info "$str $(_sgr bold)${PV}$(_sgr) for package $(_sgr bold)${PN}$(_sgr)"
}

# @see: http://www.gnu.org/prep/standards/html_node/Configuration.html
# @see: http://www.gnu.org/software/autoconf/manual/autoconf.html
function pkgConfigure()
{
	pkgbox_exec \
		${CONFIGURE_SCRIPT:-"./configure"} \
			--prefix="$INSTALLDIR" \
			"$@" \
			CFLAGS="${PKGBOX_OPTS[CFLAGS]-}" \
			CXXFLAGS="${PKGBOX_OPTS[CXXFLAGS]-}" \
			CPPFLAGS="${PKGBOX_OPTS[CPPFLAGS]-}" \
			LDFLAGS="${PKGBOX_OPTS[LDFLAGS]-}" \
			EXTRA_LDFLAGS_PROGRAM="${PKGBOX_OPTS[EXTRA_LDFLAGS_PROGRAM]-}" \
			LIBS="${PKGBOX_OPTS[LIBS]-}" \
			CC="${PKGBOX_OPTS[CC]-}" \
			CXX="${PKGBOX_OPTS[CXX]-}"
}

# @see: http://www.gnu.org/software/make/manual/make.html
function pkgMake()
{
	local make_opts=${PKGBOX_OPTS[make_opts]-}
	
	# target "install" may cause problems with parallel execution (-jX)
	make_opts=$(sed -e 's/-j[0-9]\+//g' <<<"$make_opts")
	
	pkgbox_exec \
		make $make_opts "$@"
}

