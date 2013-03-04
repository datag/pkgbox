# pkgbox #

pkgbox is a software build toolbox which eases configuring, compiling and installing software.

It is inspired by the [Gentoo Portage ebuild](http://www.gentoo.org/proj/en/devrel/handbook/handbook.xml?part=2&chap=1) system.
However, it does not resolve dependencies by itself as it should be seen as a handy utility for building software from source and not as a 
package manager nor a complete solution.


## Usage examples ##

### Print synopsis ###
	$ pkgbox -h

### Package actions ###
	$ pkgbox media-gfx/graphicsmagick install
	$ pkgbox -v -D force media-gfx/graphicsmagick configure
	$ pkgbox -vv -D prefix=$HOME/local/GraphicsMagick pkg/media-gfx/graphicsmagick/graphicsmagick.pkgbox install

### Run test suite ###
	$ pkgbox -vvv -T


## Configuration ##

Per default the configuration is stored at `$HOME/.pkgbox/conf`. An example configuration file `conf.sample` can be found in the base directory.


## Writing packages ##

Per default the package repository is located in the `pkg`-directory of the pkgbox base directory, which is a Git submodule pointing to [datag/pkgbox-packages](https://github.com/datag/pkgbox-packages).

Packages may be organized in
category directories (e.g. `app-misc`) and each package may reside in a separate directory with the name of the package (e.g. `app-misc/hello/hello.pkgbox`).

These are the ways pkgbox can be invoked with a package:

1. Complete path to `.pkgbox` file, e.g. `pkgbox /my/path/to/package.pkgbox`.
2. Specifying category plus package name, e.g. `app-misc/hello`. If no category directories are used, specify only the package name, e.g. `hello`.
3. Specify as in 2), but provide the desired package version to use (e.g. `app-misc/hello-2.7`).

### Example pkgbox-package ###

This is a minimal pkgbox package for the GNU "Hello world" program. The variable
`PKGBOX_API` and the macro `pkgVer` are mandatory.

	# pkgbox: GNU Hello
	PKGBOX_API=1
	
	pkgVer 2.8
	
	DESCRIPTION="GNU 'Hello, world!' program"
	HOMEPAGE="http://www.gnu.org/software/hello/"
	SRC_URI="http://ftp.gnu.org/gnu/$PN/$P.tar.gz"

