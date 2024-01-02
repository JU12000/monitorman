# DO NOT UPLOAD THIS PACKAGE TO THE AUR!

# Maintainer: JU12000
pkgname=monitorman-git
pkgver=1.0.0
pkgrel=1
pkgdesc="CLI tool for adding/removing and arranging bspwm desktops and monitors"
arch=('any')
url="https://github.com/JU12000/monitorman"
license=('GPL3')
depends=('bspwm' 'polybar' 'xorg-xprop' 'xorg-xrandr')
source=("$pkgname::git+$url#branch=main")

pkgver() {
	cd "$pkgname"
	git describe --long --tags | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
}

package() {
	cd "$pkgname"
	echo "$(ls $pkgname)"
	# install -Dm755 target/release/wallust -t "${pkgdir}/usr/bin"
}
