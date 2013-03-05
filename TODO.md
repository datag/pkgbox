# pkgbox TODO #

## core ##

- tool dependency checks
  - required by core: grep, egrep, sed, awk, ?
  - unpack: tar (with gzip, bz2, xz, lzma, ?), unzip, ?
  - build: make
  - fetch: wget or curl
  - SCM: git, svn, rsync(*opt)
- bash-completion file
- prepare pkgbox for UNIX-style system installation ("make install"?)
- log support
- separate file-descriptors for output/errors
- non-color-mode (per option, for non-color-terminals and default-off for non-tty)
- info screen: script version, bash version, directories, settings/options, ...
- long-options? http://mywiki.wooledge.org/BashFAQ/035
- time needed (Bash $SECONDS)
- improve usage message
- option to force re-running all actions
- option for clearing .pkgbox_{action} files to force re-run
- install-destination $D / /image
- src_install():pkgMake - get rid of general -jX stripping during install?

## packages / build-related ##

- recursive pkgbox build support
- package inheritance?
- download
  - mirror support -> scripts
  - alternate filename support
  - remember action fetch finished (cachetime?)
- SCM: support for CVS, Bazaar and Mercurial
- functions
  - version (extracting and comparing major, minor, revision, extra parts)
- add LICENSE field
- make pkgbox-files even more like Portage ebuilds
  - http://devmanual.gentoo.org/quickstart/index.html
  - http://devmanual.gentoo.org/ebuild-writing/variables/index.html
  - http://devmanual.gentoo.org/ebuild-writing/functions/index.html
  - http://devmanual.gentoo.org/function-reference/query-functions/index.html
  - http://devmanual.gentoo.org/ebuild-writing/eapi/index.html
  - http://devmanual.gentoo.org/eclass-reference/ebuild/index.html

## internals ##

- unset "unknown" variables set by pkgbox-file? or at least make most core variables read-only
- make extension .pkgbox configurable?
- quoted_args: what about other whitespace?
- always use determined $PN instead of $PKGBOX_PACKAGE
- display short, relative paths (e.g. starting at ./pkg/app-misc/... for packages)
- function-docs for build.sh and utils.sh
- set LC_ALL=C ?
- pkgbox_action_clean(): readlink-canonicalize support?
- bash "declare": multiple declaration of same type on same line
- nounset error-handler?! [b2df5fc (develop)]
	http://stackoverflow.com/questions/13103701/how-to-trap-errors-inside-the-if-statement
	http://www.unix.com/shell-programming-scripting/162336-how-trap-set-o-nounset-bash.html
	http://ubuntuforums.org/showthread.php?t=689289
	http://stackoverflow.com/questions/64786/error-handling-in-bash
- cleanup-handler
- non-debug pkgbox_debug_vars version
- declare global variables with "declare -g" and its type instead of implicit global
- verify API-Version and exit? allow ignore and continue via option
- eliminate or solve INSTALLDIR?
- clearify: --enable-static (libraries)
- clearify: -rpath
- remove unnecessary $(_sgr reset)

## tests ##

- remove jtimesched-download test
- support suppressing of stderr (e.g. for errors triggered by bash's "nounset" option)
- write tests for new functions

## readme ##

- order/precedence of option/feature assignment

