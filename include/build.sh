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
		unset -v P PV
	fi
	
	# globals
	FILESDIR="${pkg_file%/*}/files"
	WORKDIR="${PKGBOX_DIR[build]}/work"
	T="${PKGBOX_DIR[build]}/temp"
	INSTALLDIR=${O[prefix]}
	SRC_URI=()
	FEATURES=()
	
	# create directories used by build process
	mkdir -p "$WORKDIR" "$T"
	
	# debug: global vars
	pkgbox_debug_vars FILESDIR WORKDIR T INSTALLDIR P PN PV F
	
	# debug: remember all variables/functions
	if (( PKGBOX_VERBOSITY > 3 )); then
		local funcs_before=$(declare -F | cut -f3- -d' ')
		local vars_before=$(set -o posix; set)
	fi
	
	
	# include package script
	pkgbox_msg debug "Sourcing $pkg_file"
	source "$pkg_file" #|| pkgbox_die "Error initializing package $PKGBOX_PACKAGE"
	
	
	# debug: print variables/functions declared by the package script
	if (( PKGBOX_VERBOSITY > 3 )); then
		pkgbox_debug_declared_vars  vars_before  "Variables declared by package"
		pkgbox_debug_declared_funcs funcs_before "Functions declared by package"
		unset -v funcs_before vars_before
	fi
	
	# set source directory, if not set by package
	: ${S:="$WORKDIR/$P"}
	
	# determine list of files by URIs
	A=()
	if (( ${#SRC_URI[@]} )) && ! pkgUseScm; then
		for i in "${SRC_URI[@]}"; do
			A+=("${PKGBOX_DIR[download]}/${i##*/}")
		done
	fi
	
	# parse and merge features
	pkgbox_merge_features
	unset -v F_USR
	
	# debug: global vars
	pkgbox_debug_vars S SRC_URI SCM_URI A INSTALLDIR P PN PV F
	
	# declare default package actions
	pkgbox_declare_default_actions
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
				if (( ${#SRC_URI[@]} )); then
					for uri in "${SRC_URI[@]}"; do
						filename=${uri##*/}
						pkgbox_download "$uri" "$filename"
					done
				fi
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
				if (( ${#A[@]} )); then
					local filename
					for filename in "${A[@]}"; do
						pkgbox_unpack "$filename"
					done
				fi
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
	pkgbox_package_info
}

