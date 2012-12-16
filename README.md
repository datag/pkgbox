### pkgbox ####

pkgbox is a software build toolbox which eases configuring, compiling and installing software.

It is heavily inspired by the [Gentoo Portage ebuild](http://www.gentoo.org/proj/en/devrel/handbook/handbook.xml?part=2&chap=1) system.
However, it does not resolve dependencies by itself as it should be seen as a handy utility for building software from source and not a 
package manager nor a complete solution.


## Usage examples ##

	$ pkgbox -h
	$ pkgbox media-gfx/graphicsmagick install
	$ pkgbox -v -D force media-gfx/graphicsmagick configure
    $ pkgbox -vvv -D prefix=$HOME/local/GraphicsMagick pkg/media-gfx/graphicsmagick/graphicsmagick.pkgbox install

## Configuration ##

TODO

## Writing packages ##

TODO

