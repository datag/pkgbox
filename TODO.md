# pkgbox TODO #

## core ##

- tool dependency checks
- bash-completion file
- prepare pkgbox for UNIX-style system installation ("make install"?)
- log support
- don't load libs by default, require load by package
- info screen: script version, bash version, directories, settings/options, ...
- long-options? http://mywiki.wooledge.org/BashFAQ/035
- time needed (Bash $SECONDS)
- improve usage message

## packages / build-related ##

- recursive pkgbox build support
- package options / features (~USE flags)
- download
  - mirror support -> scripts
  - alternate filename support
  - SCM (git/svn) support
- functions
  - version (extracting and comparing major, minor, revision, extra parts)
  - patch
- package inheritance?
- make pkgbox-files even more like Portage ebuilds
  - http://devmanual.gentoo.org/quickstart/index.html
  - http://devmanual.gentoo.org/ebuild-writing/variables/index.html
  - http://devmanual.gentoo.org/ebuild-writing/functions/index.html
  - http://devmanual.gentoo.org/function-reference/query-functions/index.html
  - http://devmanual.gentoo.org/ebuild-writing/eapi/index.html
- package options, e.g.: F["hello"]=nls

## misc ##

- non-color-mode (per option, for non-color-terminals and default-off for non-tty)

## internals ##

- separate file-descriptors for output/errors; 
- unset "unknown" variables set by pkgbox-file? or at least make most core variables read-only
- make extension .pkgbox configurable?
- quoted_args: what about other whitespace?
- always use determined $PN instead of $PKGBOX_PACKAGE
- display short, relative paths (e.g. starting at ./pkg/app-misc/... for packages)
- function-docs for build.sh
- set LC_ALL=C ?
- test suite
	- remove jtimesched-download test
	- support suppressing of stderr (e.g. for errors triggered by bash's "nounset" option)
- pkgbox_action_clean(): readlink-canonicalize support?
- bash "declare": multiple declaration of same type on same line
- nounset error-handler?! [b2df5fc (develop)]
	http://stackoverflow.com/questions/13103701/how-to-trap-errors-inside-the-if-statement
	http://www.unix.com/shell-programming-scripting/162336-how-trap-set-o-nounset-bash.html
	http://ubuntuforums.org/showthread.php?t=689289
	http://stackoverflow.com/questions/64786/error-handling-in-bash
- cleanup-handler
- use explicit "unset -v" / "unset -f"
- fix   var="${var}additional" to var+="additional"

