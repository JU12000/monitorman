# monitorman

Monitorman allows users to automatically add/remove and configure bspwm monitors and their desktops in the specific case that they:
	1. Use a multi-monitor setup.
	2. Don't utilize all available monitors at all times.

This program is not useful for you if your multi-monitor use-case is e.g. plugging in an external monitor whenever it is to be used.

## Installation

This repository comes with a PKGBUILD file which allows the program to be installed
with the package manager in Arch-based Linux operating systems. Otherwise, the program can simply be installed by moving the `monitorman.sh` file into `usr/bin`.

## Usage

Please refer to `monitorman -h` for instructions on usage.

## Planned Improvements

1. Stop relying on polybar and instead detect the running bar and extend it.
2. Give the option to not attempt to extend the running bar.