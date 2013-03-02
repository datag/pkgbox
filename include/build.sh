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
		pkgbox_msg notice "Action #$((n - i)) $curaction"
		
		# already done?
		if [[ -f "$S/.pkgbox_$curaction" ]]; then
			if [[ $curaction == $action && ${O[force]-} ]]; then
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
	FILESDIR="${pkg_file%/*}/files"
	WORKDIR="${PKGBOX_DIR[build]}/work"
	T="${PKGBOX_DIR[build]}/temp"
	INSTALLDIR=${O[prefix]}
	SRC_URI=()
	
	# create directories used by build process
	mkdir -p "$WORKDIR" "$T"
	
	# debug: global vars
	pkgbox_debug_vars FILESDIR WORKDIR T INSTALLDIR P PN PV
	
	# debug: remember all variables/functions
	local funcs_before=$(declare -F | cut -f3- -d' ')
	local vars_before=$(set -o posix; set)
	
	# include script
	pkgbox_msg debug "Sourcing $pkg_file"
	source "$pkg_file" #|| pkgbox_die "Error initializing package $PKGBOX_PACKAGE"
	
	# debug: print variables/functions declared by the package script
	pkgbox_msg debug "Vars after:"$'\n'"$(grep -vFe "$vars_before" <<<"$(set -o posix; set)" | grep -v "^vars_before=")"
	pkgbox_msg debug "Funcs after:"$'\n'"$(grep -vFe "$funcs_before" <<<"$(declare -F | cut -f3- -d' ')" || true)"
	
	
	# set source directory, if not set by package
	: ${S:="$WORKDIR/$P"}
	
	# determine list of files by URIs
	A=()
	for i in "${SRC_URI[@]-}"; do
		A+=("${PKGBOX_DIR[download]}/${i##*/}")
	done
	
	
	# debug: global vars
	pkgbox_debug_vars S SRC_URI A INSTALLDIR P PN PV
	
	# declare default package actions
	pkgbox_declare_default_actions
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

# Declare default package actions
function pkgbox_declare_default_actions()
{
	# src_fetch(): Download source package or checkout SCM repository
	if ! pkgbox_is_function "src_fetch"; then
		function src_fetch()
		{
			local uri filename
			pkgbox_msg debug "Default src_fetch()"
			
			# whether to download files or checkout repository
			if ! pkgUseScm; then
				# regular download
				for uri in "${SRC_URI[@]-}"; do
					filename=${uri##*/}
					pkgbox_download "$uri" "$filename"
				done
			else
				# SCM repository
				pkgbox_scm_checkout "$SCM_URI" $PV $PN
				
				# need to synchronize repository copy
				rm -f "$S/.pkgbox_unpack"
			fi
		}
	fi	
	
	# src_unpack(): Extract source package or copy SCM repository
	if ! pkgbox_is_function "src_unpack"; then
		function src_unpack()
		{
			pkgbox_msg debug "Default src_unpack()"
			
			# whether to extract or locally copy the SCM repository
			if ! pkgUseScm; then
				local filename
				for filename in "${A[@]-}"; do
					pkgbox_unpack "$filename"
				done
			else
				# synchronize repository copy with that of in PKGBOX_DIR[download]
				local v=
				(( PKGBOX_VERBOSITY > 1 )) && v="-v"
				
				if pkgbox_is_command rsync; then
					mkdir -p "$S"		# needed when using package versions like "tags/release-1.0.0"
					rsync -a $v "${PKGBOX_DIR[download]}/$PN/" "$S"
				else
					# use plain copy if rsync is not available
					(
						cd "${PKGBOX_DIR[download]}/$PN"
						mkdir -p "$S" && cp $v -rfu -t "$S" .
					)
				fi
			fi
		}
	fi
	
	# src_prepare(): Does nothing
	if ! pkgbox_is_function "src_prepare"; then
		function src_prepare()
		{
			pkgbox_msg debug "Default src_prepare()"
		}
	fi
	
	# src_configure(): Executes "configure"
	if ! pkgbox_is_function "src_configure"; then
		function src_configure()
		{
			pkgbox_msg debug "Default src_configure()"
			
			pkgConfigure
		}
	fi
	
	# src_compile(): Executes "make"
	if ! pkgbox_is_function "src_compile"; then
		function src_compile()
		{
			pkgbox_msg debug "Default src_compile()"
			
			pkgMake
		}
	fi
	
	# src_install(): Executes "make install"
	if ! pkgbox_is_function "src_install"; then
		function src_install()
		{
			pkgbox_msg debug "Default src_install()"
			
			pkgMake install
		}
	fi
	
	return 0
}

function pkgbox_action_fetch()
{
	pkgbox_msg debug "src_fetch()"
	
	src_fetch
}

function pkgbox_action_unpack()
{
	pkgbox_msg debug "src_unpack()"
	
	src_unpack
	touch "$S/.pkgbox_unpack"
}

function pkgbox_action_prepare()
{
	pkgbox_msg debug "src_prepare()"
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
	
	src_prepare
	touch "$S/.pkgbox_prepare"
}

function pkgbox_action_configure()
{
	pkgbox_msg debug "src_configure()"
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
	
	src_configure
	touch "$S/.pkgbox_configure"
}

function pkgbox_action_compile()
{
	pkgbox_msg debug "src_compile()"
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
	
	src_compile
	touch "$S/.pkgbox_compile"
}

function pkgbox_action_install()
{
	pkgbox_msg debug "src_install()"
	
	pkgbox_msg debug "Changing current working directory to $S"
	cd "$S"
	
	[[ ! -d $INSTALLDIR ]] && mkdir -p "$INSTALLDIR"
	src_install
	touch "$S/.pkgbox_install"
}

function pkgbox_action_clean()
{
	local filename
	
	pkgbox_msg debug "clean()"
	
	pkgbox_msg notice "Removing '$PN' working directory"
	[[ ${S:0:${#WORKDIR}} == $WORKDIR ]] || pkgbox_die "Invalid working directory '$S'"
	rm -rf "$S" &>/dev/null
}

function pkgbox_action_info()
{
	local str uri
	
	if ! pkgUseScm; then
		uri="Source URIs: ${SRC_URI[@]:-"n/a"}"
	else
		uri="SCM URI:     ${SCM_URI:-"n/a"}"
	fi
	
	local str=$(cat <<-EOT
		pkgbox package $(_sgr bold)${P}$(_sgr)  (API version: $PKGBOX_API)
		
		    Package:     $(_sgr bold)${PN}$(_sgr)
		    Version:     $(_sgr bold)${PV}$(_sgr)
		    Description: ${DESCRIPTION:-"n/a"}
		    Homepage:    ${HOMEPAGE:-"n/a"}
		    ${uri}
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

function pkgUseScm()
{
	if [[ ${SCM_URI-} ]] && ! pkgbox_is_int "${PV:0:1}"; then
		return 0
	else
		return 1
	fi
}

# @see: http://www.gnu.org/prep/standards/html_node/Configuration.html
# @see: http://www.gnu.org/software/autoconf/manual/autoconf.html
function pkgConfigure()
{
	pkgbox_exec \
		${CONFIGURE_SCRIPT:-"./configure"} \
			--prefix="$INSTALLDIR" \
			"$@" \
			CFLAGS="${O[CFLAGS]-}" \
			CXXFLAGS="${O[CXXFLAGS]-}" \
			CPPFLAGS="${O[CPPFLAGS]-}" \
			LDFLAGS="${O[LDFLAGS]-}" \
			EXTRA_LDFLAGS_PROGRAM="${O[EXTRA_LDFLAGS_PROGRAM]-}" \
			LIBS="${O[LIBS]-}" \
			CC="${O[CC]-}" \
			CXX="${O[CXX]-}"
}

# @see: http://www.gnu.org/software/make/manual/make.html
function pkgMake()
{
	local make_opts=${O[make_opts]-}
	
	# target "install" may cause problems with parallel execution (-jX)
	make_opts=$(sed -e 's/-j[0-9]\+//g' <<<"$make_opts")
	
	pkgbox_exec \
		make $make_opts "$@"
}

