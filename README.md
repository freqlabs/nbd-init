# rc.reroot init hook

## Background

From [this mailing list post](https://lists.freebsd.org/pipermail/freebsd-announce/2016-February/001706.html):

	One of the long-missing features of FreeBSD was the ability to boot up
	with a temporary rootfs, configure the kernel to be able to access the
	real rootfs, and then replace the temporary root with the real one. In
	Linux, this functionality is known as pivot_root. The reroot projects
	provides similar functionality in a different, slightly more
	user-friendly way: rerooting. Simply put, from the user point of view
	it looks like the system performs a partial shutdown, killing all
	processes and unmounting the rootfs, and then partial bringup, mounting
	the new rootfs, running init, and running the startup scripts as usual.

## ~~Overview~~ Details

In a reroot, all user processes are terminated before unmounting the old root
filesystem and mounting a new one.  This means GEOM Gate devices and other
storage providers that rely on a userspace component cannot be used for a root
filesystem, as the I/O will hang indefinitely once the process providing the
data is killed.

To resolve this issue, a hook can be added to init that runs a script during a
reroot after shutting down the running processes but before attempting to mount
the new root filesystem.  This gives an administrator the opportunity to copy
their storage provider program to the reroot tmpfs and launch it as a daemon,
thus providing the storage volumes from which to mount the new root filesystem.

The placement of the hook must be after the reroot tmpfs has been mounted to
`/dev/reroot` but before the old root filesystem has been replaced.  This lets
the hook be used to copy any needed daemons to the reroot tmpfs so that the
root filesystem remains unused and is free to be replaced after the script
exits.

## Getting Started

This repo contains a modified copy of `init(8)` from the FreeBSD 11-STABLE repo
along with some example files to demonstrate one way the hook can be used.

In this example, an `md(4)` root image boots the kernel and attaches an NBD
volume, then reroots to a ZFS pool on this volume.

A boot image can be prepared by making the following modifications to a
FreeBSD 11 or later mfsbsd.img, mini-memstick.img or similar:

+ `/sbin/init` replaced with the modified `init`
+ an NBD client at `/sbin/nbd-client`
+ `/etc/rc` replaced with a short script to bring up network interfaces and
  immediately begin the reroot process (example in `etc/`)
+ the reroot hook script `/etc/rc.reroot`, which copies the NBD client to the
  reroot tmpfs in `/dev/reroot/`, starts the client, and updates the kernel
  environment for the new root filesystem (example in `etc/`)

The example `loader.conf` in `boot/` can be used with a custom built root
memdisk akin to how mfsbsd is built, as a demonstration of configuring the
system's storage location from `loader.conf`.  Alternatively, you might fetch
the server configuration from a metadata API (or hard code it) in `rc.reroot`.

The ZFS pool is a full install of FreeBSD made using `bsdinstall` to an `md(4)`
attached image file or a zvol.  The only special requirement is to not use DHCP
on the network interface `nbd-client` is bound to or otherwise interrupt that
connection, and manually specify your DNS servers in `/etc/resolv.conf`
instead.

## Building

### init (required)

The `Makefile` is modified to build out of tree and dependencies have been
copied into this repo, for convenience. Building on FreeBSD works as you would
expect:

```
git clone https://github.com/freqlabs/nbd-init
cd nbd-init
make
```

The patch against the original `init` code can be found in `patch/`.

### NBD (optional)

The NBD client can be found
[here](https://github.com/freqlabs/nbd-client/tree/casper).  To avoid library
dependency issues, statically link the client by building with
`LDFLAGS=-static`:

```
git clone -b casper https://github.com/freqlabs/nbd-client
cd nbd-client
make LDFLAGS=-static
```

An NBD server creatively named `nbd-server` is available in the ports tree or
package repo to serve the root pool image for the purpose of this example.

## Caveats

The `/etc/rc.reroot` script is mandatory for a reroot to succeed in this
implementation, which may not be the ideal solution.  The script can simply be
an empty file, but if it cannot be read or exits with an error, `init` will
drop the system to single user mode in the middle of the reroot process.

Shutdown and reboot have not yet been addressed for the "root on a userland
client" use case and are humorously ungraceful at this time.

## Possibilities

The example could easily be adapted to use `ggated(8)` and `ggatec(8)` instead
of `nbd-server` and `nbd-client`.

In the future, a userland RBD client for
[Ceph](http://ceph.com/ceph-storage/block-storage/) could take advantage of
this same mechanism to mount FreeBSD's root filesystem from from a cluster
backed, thinly provisioned machine image.
