# core tests
################################################################################

# test wrapper
function _t()
{
	local exp=$1 cmd=$2 code out text
	
	#set -x
	out=$(eval "$cmd")
	code=$?
	#set +x
	
	# expected value is either a match or not-match (prefixed with "!")
	if [[ (${exp:0:1} != '!' && $code != $exp) || (${exp:0:1} == '!' && $code == ${exp:1:${#exp}-1}) ]]; then
		text="$(_sgr fg=red reverse)FAIL"
		((tests_failed++)) || true
	else
		text="$(_sgr fg=green reverse)PASS"
	fi
	text="$text $(printf "exp:% 4s got:% 3s" $exp $code)$(_sgr)"
	[[ -n "$out" ]] && out=" ($(_sgr bold)output:$(_sgr) $out)"
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

declare -i tests_run=0
declare -i tests_failed=0

################################################################################
################################################################################
pkgbox_msg info "pkgbox_include()"

_t !0 "pkgbox_include"
for i in !0:'' 0:'include/basic.sh' !0:'foobar'; do
	_expval "$i"
	_t $e "pkgbox_include '$v'"
done

################################################################################
pkgbox_msg info "pkgbox_msg()"

_t 0 "pkgbox_msg"
for i in 0:'' 0:'debug' 0:'info' 0:'notice' 0:'warn' 0:'error' 0:'fatal' 0:'foobar'; do
	_expval "$i"
	_t $e "pkgbox_msg '$v' 'This is a test with level \"${v^^}\"'"
done


################################################################################
pkgbox_msg info "pkgbox_is_int()"

_t !0 "pkgbox_is_int"
for i in 0:1 0:12 0:0 0:-1 0:-12 !0:0.0 !0:1.0 !0:-1.0 !0:+3 !0:1a !0:a1 !0:-a1 !0:-1a !0:'' !0:' '; do
	_expval "$i"
	_t $e "pkgbox_is_int '$v'"
done

################################################################################
pkgbox_msg info "pkgbox_is_function()"

_t !0 "pkgbox_is_function"
for i in !0:'' 0:'pkgbox_echo' !0:'_nonexist_function'; do
	_expval "$i"
	_t $e "pkgbox_is_function '$v'"
done

################################################################################
pkgbox_msg info "pkgbox_is_command()"

_t !0 "pkgbox_is_command"
for i in !0:'' 0:'source' 0:'bash' !0:'include/basic.sh' !0:'_nonexist_command'; do
	_expval "$i"
	_t $e "pkgbox_is_command '$v'"
done

################################################################################
pkgbox_msg info "pkgbox_byteshuman()"

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

################################################################################
pkgbox_msg info "pkgbox_rndstr()"

_t 0 "pkgbox_rndstr"
for i in 0:'' !0:' ' !0:'a' 0:0 0:5; do
	_expval "$i"
	_t $e "pkgbox_rndstr '$v'"
done
for i in 0:'' 0:' ' 0:'a-c' ; do
	_expval "$i"
	_t $e "pkgbox_rndstr '10' '$v'"
done

################################################################################
pkgbox_msg info "pkgbox_download()"

_t !0 "pkgbox_download"
_t !0 "pkgbox_download 'http://www.dominik-geyer.de/files/jTimeSched/jTimeSched-latest.zip' 'jTimeSched-1.1.zip' '/proc'"
_t !0 "pkgbox_download 'http://www.dominik-geyer.de/files/jTimeSched/nope.zip' 'jTimeSched-1.1.zip' '/tmp'"
_t  0 "pkgbox_download 'http://www.dominik-geyer.de/files/jTimeSched/jTimeSched-latest.zip' 'jTimeSched-1.1.zip' '/tmp'"
_t  0 '[[ "$(md5sum /tmp/jTimeSched-1.1.zip | cut -f1 -d" ")" == "60fb7a599792e2a41982a3d23ef1813d" ]]'

################################################################################
################################################################################
# summary
pkgbox_msg info "tests run   : $tests_run"
pkgbox_msg info "tests passed: $((tests_run - tests_failed))"
(( tests_failed > 0 )) && pkgbox_msg warn "tests failed: $(_sgr fg=red reverse)$tests_failed$(_sgr)"

# set exit code to zero
true
