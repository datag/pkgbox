# pkgbox #

pkgbox is a software build toolbox which eases configuring, compiling and installing software.

It is heavily inspired by the [Gentoo Portage ebuild](http://www.gentoo.org/proj/en/devrel/handbook/handbook.xml?part=2&chap=1) system.
However, it does not resolve dependencies by itself as it should be seen as a handy utility for building software from source and not as a 
package manager nor a complete solution.


## Usage examples ##

### Print synopsis ###
	$ pkgbox -h

### Package actions ###
	$ pkgbox media-gfx/graphicsmagick install
	$ pkgbox -v -D force media-gfx/graphicsmagick configure
	$ pkgbox -vvv -D prefix=$HOME/local/GraphicsMagick pkg/media-gfx/graphicsmagick/graphicsmagick.pkgbox install

### Run test suite ###
	$ pkgbox -vvv -T


## Configuration ##

Per default the configuration is stored at `$HOME/.pkgbox/conf`. An example configuration file `conf.sample` can be found in the base directory.


## Writing packages ##

Example pkgbox-package for the GNU "Hello world" program.

	# pkgbox: GNU Hello
	PKGBOX_API=1
	
	# http://www.gnu.org/software/hello/manual/
	
	pkgVer 2.8
	
	DESCRIPTION="GNU 'Hello, world!' program"
	HOMEPAGE="http://www.gnu.org/software/hello/"
	SRC_URI="http://ftp.gnu.org/gnu/$PN/$P.tar.gz"

