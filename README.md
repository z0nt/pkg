FreeBSD in packages
===================

To build and put world in packages run the following:
./builder -r /repo world

To build and put kernel in packages run the following:
./builder -r /repo -k /sys/amd64/conf/GENERIC kernel
