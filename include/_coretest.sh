# core tests
# FIXME: possibility to assert output of stdout (maybe even stderr) as well
################################################################################

# test wrapper
function _t()
{
	local exp=$1 cmd=$2 code=0 out text
	
	#set -x
	out=$(eval "$cmd") || code=$?
	#set +x
	
	# expected value is either a match or not-match (prefixed with "!")
	if [[ (${exp:0:1} != '!' && $code != $exp) || (${exp:0:1} == '!' && $code == ${exp:1:${#exp}-1}) ]]; then
		text="$(_sgr fg=red reverse)FAIL"
		((tests_failed++)) || true
	else
		text="$(_sgr fg=green reverse)PASS"
	fi
	text="$text $(printf "exp:% 4s got:% 3s" $exp $code)$(_sgr)"
	[[ -n "$out" ]] && out=" ($(_sgr bold)output:$(_sgr) $(_sgr fg=blue underline)$out$(_sgr))"
	pkgbox_msg test "$text $(_sgr underline)$cmd$(_sgr)$out"
	
	((tests_run++)) || true
	
	return 0
}

# split "exp:val" into global variables e (expect) and v (value)
function _expval()
{
	# global
	e="${1%%:*}"
	v="${1#*:}"
}

function _run_tests()
{
	declare -i tests_run=0
	declare -i tests_failed=0
	
	declare -a tests=(
		pkgbox_include
		pkgbox_msg
		pkgbox_int
		pkgbox_is_function
		pkgbox_is_command
		pkgbox_byteshuman
		pkgbox_rndstr
		pkgbox_trim
		pkgbox_print_quoted_args
		pkgbox_exec
		pkgbox_download
	)
	
	local testfunc t
	
	for t in ${tests[@]}; do
		testfunc="_test_$t"
		if ! pkgbox_is_function $testfunc; then
			pkgbox_msg warn "Skipping test $t: Function does not exist"
			continue
		fi
		
		pkgbox_echo -e "\n$(_sgr fg=black reverse)  RUNNING TESTS    $(printf "% 59s" "$t")  " >&2
		$testfunc
		
		# unset commonly used variables
		unset i j k  e v   # i to k = loop variables used in tests; e and v = global expected:value
	done
	
	################################################################################
	# summary
	pkgbox_msg info "tests run   : $tests_run"
	pkgbox_msg info "tests passed: $((tests_run - tests_failed))"
	(( tests_failed > 0 )) && pkgbox_msg warn "tests failed: $(_sgr fg=red reverse)$tests_failed"

	# clean exit
	return 0
}

################################################################################
_test_pkgbox_include()
{
	_t !0 "pkgbox_include"
	for i in !0:'' 0:'include/basic.sh' !0:'foobar'; do
		_expval "$i"
		_t $e "pkgbox_include '$v'"
	done
}

################################################################################
_test_pkgbox_msg()
{
	_t 0 "pkgbox_msg"
	for i in 0:'' 0:'debug' 0:'info' 0:'notice' 0:'warn' 0:'error' 0:'fatal' 0:'foobar'; do
		_expval "$i"
		_t $e "pkgbox_msg '$v' 'This is a test with level \"${v^^}\"'"
	done
}

################################################################################
_test_pkgbox_int()
{
	_t !0 "pkgbox_is_int"
	for i in 0:1 0:12 0:0 0:-1 0:-12 !0:0.0 !0:1.0 !0:-1.0 !0:+3 !0:1a !0:a1 !0:-a1 !0:-1a !0:'' !0:' '; do
		_expval "$i"
		_t $e "pkgbox_is_int '$v'"
	done
}

################################################################################
_test_pkgbox_is_function()
{
	_t !0 "pkgbox_is_function"
	for i in !0:'' 0:'pkgbox_echo' !0:'_nonexist_function'; do
		_expval "$i"
		_t $e "pkgbox_is_function '$v'"
	done
}

################################################################################
_test_pkgbox_is_command()
{
	_t !0 "pkgbox_is_command"
	for i in !0:'' 0:'source' 0:'bash' !0:'include/basic.sh' !0:'_nonexist_command'; do
		_expval "$i"
		_t $e "pkgbox_is_command '$v'"
	done
}

################################################################################
_test_pkgbox_byteshuman()
{
	_t 0 "pkgbox_byteshuman"
	for i in $(seq 0 5); do	v=$((1024**i));
		for j in $((v-1)) $((v)) $((v+1)) $((v*512)); do
			_t 0 "pkgbox_byteshuman '$j'"
		done
	done
	for i in 0:'' !0:' ' !0:'a' !0:-1025 !0:1.025; do
		_expval "$i"
		_t $e "pkgbox_byteshuman '$v'"
	done
}

################################################################################
_test_pkgbox_rndstr()
{
	_t 0 "pkgbox_rndstr"
	for i in 0:'' !0:' ' !0:'a' 0:0 0:5; do
		_expval "$i"
		_t $e "pkgbox_rndstr '$v'"
	done
	for i in 0:'' 0:' ' 0:'a-c' ; do
		_expval "$i"
		_t $e "pkgbox_rndstr '10' '$v'"
	done
}

################################################################################
_test_pkgbox_trim()
{
	_t 0 "pkgbox_trim"
	_t 0 "pkgbox_trim foo"
	_t 0 "pkgbox_trim '  foo  '"
	_t 0 "pkgbox_trim 'foo  '"
	_t 0 "pkgbox_trim '  foo'"
	_t 0 "pkgbox_trim ' foo    bar '"
	_t 0 "pkgbox_trim '  foo    bar  '"
	_t 0 "pkgbox_trim ' foo  bar  baz '"
	_t 0 "pkgbox_trim 'foo  bar  '"
	_t 0 "pkgbox_trim '  foo  bar'"
}

################################################################################
_test_pkgbox_print_quoted_args()
{
	_t 0 "pkgbox_print_quoted_args"
	_t 0 "pkgbox_print_quoted_args --foo --bar"
	_t 0 "pkgbox_print_quoted_args --foo 'bar    baz'"
	_t 0 "pkgbox_print_quoted_args --foo 'bar '\\'' baz'"
	_t 0 "pkgbox_print_quoted_args \\'"
}

################################################################################
_test_pkgbox_exec()
{
	_t 0 "pkgbox_exec"
	_t 0 "pkgbox_exec date"
	_t 0 "pkgbox_exec date --rfc-2822"
	_t 0 "pkgbox_exec date +'%Y-%m-%d   %H:%M:%S'"
	_t 0 "pkgbox_exec date +'%Y-%m-%d   '\\''   %H:%M:%S'"
	_t 0 "echo 'foo   bar' | pkgbox_exec tr '[:lower:]' '[:upper:]'"
	_t 0 "pkgbox_exec head -n 1 </etc/hosts"
	_t !0 "pkgbox_exec false"
	_t 0 "pkgbox_exec 'uname -o' -m"   # e.g. having "gm convert" as "single unit"
}

################################################################################
_test_pkgbox_download()
{
	# cleanup
	local pkg_url='http://www.dominik-geyer.de/files/jTimeSched/jTimeSched-latest.zip'
	local pkg_file="jTimeSched-1.1 with space.zip"
	local pkg_filepath="${PKGBOX_DIR[download]}/$pkg_file"
	
	[[ -f "$pkg_filepath" ]] && rm "$pkg_filepath"
	
	_t !0 "pkgbox_download"
	_t !0 "pkgbox_download \"$pkg_url\" \"$pkg_file\" \"/proc\""
	_t !0 "pkgbox_download \"${pkg_url%/*}/_nonexist_file.zip\" \"$pkg_file\""
	_t  0 "pkgbox_download \"$pkg_url\" \"$pkg_file\""
	_t  0 "[[ \"\$(md5sum '$pkg_filepath' | cut -f1 -d' ')\" == \"60fb7a599792e2a41982a3d23ef1813d\" ]]"
}
