#!/bin/sh
#

umask 0022

pre()
{

	workdir="`mktemp -d -t builder`" || exit 1
	mount -o size=$((1<<30)) -t tmpfs tmpfs $workdir
}

post()
{

	umount $workdir || true
	rmdir $workdir
}

mk_kernel()
{
	local _conf

	make -s -C $src -j $jobs buildkernel KERNCONF=$kernconf KERNCONFDIR=$kernconfdir
	make -s -C $src installkernel KERNCONF=$kernconf KERNCONFDIR=$kernconfdir DESTDIR=$workdir

	for _conf in $conf; do
		$pkgdir/helper $pkgdir/${_conf} $workdir $repo
	done
}

mk_rescue()
{
	local _conf

	make -s -C $src/rescue
	make -s -C $src hierarchy DESTDIR=$workdir > /dev/null
	make -s -C $src/rescue install DESTDIR=$workdir
	make -s -C $src/rescue clean
	make -s -C $src/rescue cleandepend

	cp /usr/local/sbin/pkg-static $workdir/rescue/pkg

	for _conf in $conf; do
		$pkgdir/helper $pkgdir/${_conf} $workdir $repo
	done
}

mk_world()
{
	local _conf

	make -s -C $src -j $jobs buildworld
	make -s -C $src installworld DESTDIR=$workdir
	make -s -C $src distribution DESTDIR=$workdir

	cp $workdir/etc/master.passwd $workdir/usr/share/examples/etc
	cp /usr/local/sbin/pkg-static $workdir/rescue/pkg

	for _conf in $conf; do
		$pkgdir/helper $pkgdir/${_conf} $workdir $repo
	done
}

mk_zoneinfo()
{
	local _conf

	make -s -C $src/share/zoneinfo
	make -s -C $src hierarchy DESTDIR=$workdir > /dev/null
	make -s -C $src/share/zoneinfo install DESTDIR=$workdir
	make -s -C $src/share/zoneinfo clean

	for _conf in $conf; do
		$pkgdir/helper $pkgdir/${_conf} $workdir $repo
	done
}

usage()
{

	echo 1>&2 "usage: buidler [options] <kernel|rescue|world|zoneinfo>"
	echo 1>&2 ""
	echo 1>&2 "  Options:"
	echo 1>&2 "    -c path  List of configuration files"
	echo 1>&2 "    -j num   Number of parallel jobs (default: number of CPUs)"
	echo 1>&2 "    -k path  Path to kernel configuration file"
	echo 1>&2 "    -r path  Path to pkgng repo"
	echo 1>&2 "    -s path  Alternate path to src (default: /usr/src)"
	echo 1>&2 ""

	exit 1
}

if [ $# -lt 1 ]; then
	usage
fi

kernel_conf="freebsd-kernel.conf freebsd-kernel-symbols.conf"
rescue_conf="freebsd-rescue.conf"
world_conf="freebsd-base.conf freebsd-lib32.conf freebsd-rescue.conf freebsd-zoneinfo.conf"
zoneinfo_conf="freebsd-zoneinfo.conf"

jobs="`sysctl -n hw.ncpu`"
src="/usr/src"

pkgdir="`dirname $0`" # XXX

while getopts "c:j:hk:r:s:" opt; do
	case "$opt" in
	c) conf="$OPTARG" ;;
	j) jobs="$OPTARG" ;;
	k) kernconf="$OPTARG" ;;
	r) repo="$OPTARG" ;;
	s) src="$OPTARG" ;;
	*) usage ;;
	esac

	shift $(($OPTIND - 1))
done

if [ $# -ne 1 ]; then
	usage
fi

target="$1"

if [ "$target" = "kernel" -a -z "${kernconf:-}" ]; then
	echo 1>&2 "Please specify kernel config file"
	exit 1
fi

if [ -z "${repo:-}" ]; then
	echo 1>&2 "Please specify repo directory"
	exit 1
fi

repo="`realpath $repo`"

if [ ! -d "$repo" -o ! -d "$repo/All" ]; then
	echo 1>&2 "Please create \"$repo\" and \"$repo/All\""
	exit 1
fi

set -eux

trap "post" EXIT
trap "exit 0" SIGINT
pre

case "$target" in
kernel)
	kernconf="`realpath $kernconf`"
	kernconfdir="`dirname $kernconf`"
	kernconf="`basename $kernconf`"
	: ${conf:=$kernel_conf}
	mk_kernel
	;;
rescue)
	: ${conf:=$rescue_conf}
	mk_rescue
	;;
world)
	: ${conf:=$world_conf}
	mk_world
	;;
zoneinfo)
	: ${conf:=$zoneinfo_conf}
	mk_zoneinfo
	;;
*)
	usage
	;;
esac

pkg repo $repo
