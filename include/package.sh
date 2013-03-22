# Returns package version parts ($P $PN $PV) by package string considering default version
# @param string Package string, e.g. app-misc/hello-2.8
# @param [string] Override version
# @return string Parts separated by space: "name-version name version"
function pkgbox_package_version_parts()
{
	local p=${1##*/} pn pv=${2-}	# strip dirname from package, if any
	p=${p%.pkgbox}					# strip extension, if set
	
	local regex='^(.*)(-[0-9\.]+[a-zA-Z_]*[0-9\.]*(-[a-zA-Z][0-9]+)?)$'
	if [[ $p =~ $regex ]]; then
		pn=${BASH_REMATCH[1]}
		
		if [[ ! $pv ]]; then		# version override
			pv=${BASH_REMATCH[2]}
			pv=${pv:1}				# cut off first dash
		fi
		
		p="$pn-$pv"
	else
		pn=$p
	fi
	
	if [[ $pv ]]; then
		p="$pn-$pv"
	fi
	
	echo "$p $pn $pv"
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
			"${PKGBOX_DIR[packages]}/${category}/${l_p}.pkgbox"
			"${PKGBOX_DIR[packages]}/${category}/${l_pn}.pkgbox"
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

# a) foo     [yes]
# b) foo=    [empty/no]
# c) foo=bar [value/yes]
# d) foo=y   [yes]
# e) foo=n   [no]
function pkgbox_parse_feature()
{
	local f=$1 p=${2-0}
	local fn=$f fv=y o
	
	case "$f" in
	 -*) # disable feature (remove any value (=*), if present)
	 	fn=${f:1}; fn=${fn%%=*}; fv=n
	 	;;
	*=*) # enable feature and set value (remove leading "+", if present)
		fn=${f%%=*}; fn=${fn#+}; fv=${f#*=}
		;;
	 +*) # enable feature
	 	fn=${f:1}; fv=y
	 	;;
	esac
	
	if (( p == 1 )); then
		o="$fn"
	elif (( p == 2 )); then
		o="$fv"
	else
		o="$fn=$fv"
	fi
	
	echo "$o"
}

# 1) Package feature defaults
# 2) Feature override via config file
# 3) Feature override via option -F
function pkgbox_merge_features()
{
	# prepend package default features to combined features (config + user-override)
	if (( ${#FEATURES[@]} && ${#F_USR[@]} )); then
		F_USR=("${FEATURES[@]}" "${F_USR[@]}")
	elif (( ${#FEATURES[@]} )); then
		F_USR=("${FEATURES[@]}")
	fi
	
	# move all package features into global $F
	local i fn fv
	for i in "${!F_USR[@]}"; do
		fn=$(pkgbox_parse_feature "${F_USR[$i]}" 1)
		fv=$(pkgbox_parse_feature "${F_USR[$i]}" 2)
		
		F[$fn]=$fv
	done
}

pkgbox_package_info()
{
	local str i fn fv \
		def v a
	
	local str=$(cat <<-EOT
		
		$(_sgr underline)pkgbox package    $(_sgr bold)${P}$(_sgr)  (API version: $PKGBOX_API)
		    
		   Package name:  $(_sgr bold)${PN}$(_sgr)
		        Version:  $(_sgr bold)${PV}$(_sgr)
		    Description:  ${DESCRIPTION--}
		       Homepage:  ${HOMEPAGE--}
	EOT
	)
	
	# SRC_URI / SCM_URI
	if ! pkgUseScm; then
		str+=$'\n'"    Source URIs:  ${SRC_URI[@]--}"
	else
		str+=$'\n'"        SCM URI:  ${SCM_URI--}"
	fi
	
	# features
	if (( ${#FEATURES[@]} )); then
		str+=$'\n'"       Features:"
		
		function _pkgbox_feature_format {
			# use $v and $a of above scope
			case "$1" in
			y)  v=YES   a="fg=green" ;;
			n)  v=NO    a="fg=red"   ;;
			"") v="{EMPTY VALUE}" a="fg=cyan" ;;
			*)  v=$1    a="fg=black underline" ;;
			esac
		}
	
		for i in "${!FEATURES[@]}"; do
			fn=$(pkgbox_parse_feature "${FEATURES[$i]}" 1)
			fv=$(pkgbox_parse_feature "${FEATURES[$i]}" 2)
		
			# package default overridden (different)?
			[[ ${F[$fn]} != $fv ]] && def=1 || def=
		
			str+=$'\n'"$(_sgr ${def:+bold} fg=blue)$(printf "% 20s" "$fn")$(_sgr)"
			_pkgbox_feature_format "${F[$fn]}"
			str+="  $(_sgr ${def:+bold} $a)${v}$(_sgr)"
			
			if [[ $def ]]; then
				_pkgbox_feature_format "$fv"
				str+="    [$(_sgr $a)${v}$(_sgr)]"
			fi
		done
	
		unset -f _pkgbox_feature_format
	fi
	
	pkgbox_echo "$str"$'\n' >&2
}

################################################################################
# package functions

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

# @use CONFIGURE_SCRIPT: Configure script (default: ./configure)
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

function pkgUse()
{
	pkgUseIsset "$1" && [[ ${F[$1]-} != "n" ]]		# empty value counts as enabled
}

:<<'EOC'
function pkgUseHasValue()
{
	pkgUse "$1" && [[ $(pkgUseValue "$1") ]]
}
EOC

function pkgUseValue()
{
	[[ ${F[$1]-} != "" && ${F[$1]-} != "n" && ${F[$1]-} != "y" ]] && echo "${F[$1]}"
}


function pkgUseIsset()
{
	[[ ${F[$1]+__KEY_ISSET} == __KEY_ISSET ]]
}

# $1 = true-verb, $2 = false-verb, $3 = feature name, ${4-} = configure feature, ${5-} = mode (default: "-"), ${6-} = value override
# e.g. pkgConfigureOption enable disable nls
# e.g. pkgConfigureOption enable disable nls languages
# e.g. pkgConfigureOption with without devrandom
# e.g. pkgConfigureOption with without devrandom -omitempty
# e.g. pkgConfigureOption with without ssl openssl - "$my_value"
function pkgConfigureOption()
{
	local cfgtrue=$1 cfgfalse=$2 fn=$3 confn=${4-} mode=${5:-"-"} custom=${6-} \
		cfg val= invert=0 rc=0
	
	# feature prefixed with "!" inverts the logic
	[[ ${fn:0:1} == "!" ]] && invert=1 fn=${fn:1}
	
	# test for feature and store non-zero result
	pkgUse "$fn" || rc=$?
	
	# the actual inversion
	(( $invert )) && rc=$(( ! rc ))
	
	# whether to use the true-verb (e.g. enable) or the false-verb (e.g. disable)
	if (( $rc == 0 )); then
		cfg=$cfgtrue
		
		if (( $# < 6 )); then
			# use feature' set value
			[[ ${F[$fn]-} != y ]] && val="=${F[$fn]-}"
		else
			val="=$custom"
		fi
	else
		cfg=$cfgfalse
	fi
	
	# special case: do not print option if value is empty (w/o "=") and mode is "omitempty"
	if [[ ${#val} > 1 || $mode != "-omitempty" ]]; then
		echo "--${cfg}-${confn:-$fn}${val}"
	fi
}

function pkgEnable()
{
	pkgConfigureOption "enable" "disable" "$@"
}

function pkgWith()
{
	pkgConfigureOption "with" "without" "$@"
}

