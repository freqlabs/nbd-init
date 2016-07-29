# reroot init hook

## Overview

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

## What Are These Files

This repo contains a modified copy of `init(8)` from the FreeBSD 11-STABLE repo
along with some example files to demonstrate one way the hook can be used.

In this example, an `md(4)` root image boots the kernel and attaches an NBD
volume, then reroots to a ZFS pool on this volume.

The boot image has `/sbin/init` replaced with the modified init, an NBD client
at `/sbin/nbd-client`, `/etc/rc` replaced with a short script to bring up
network interfaces and immediately begin the reroot process, and the reroot
hook script `/etc/rc.reroot`, which copies the NBD client to the reroot tmpfs
in `/dev/reroot/`, starts the client, and updates the kernel environment for
the new root filesystem.

The ZFS pool is a full install of FreeBSD made using `bsdinstall` to an `md(4)`
attached image file or a zvol.  The only special requirement is to not use DHCP
on the network interface `nbd-client` is bound to or otherwise interrupt that
connection, and manually specify your DNS servers in `/etc/resolv.conf`
instead.

An NBD server creatively named `nbd-server` is available in the ports tree or
package repo to serve the root pool image for the purpose of this example.  The
NBD client can be found
[here](https://github.com/freqlabs/nbd-client/tree/casper).

The `Makefile` is modified to build out of tree and dependencies copied into
this repo, for convenience.

## Caveats

The `/etc/rc.reroot` script is mandatory for a reroot to succeed in this
implementation, which may not be the ideal solution.  The script can simply be
an empty file, but if it cannot be read or exits with an error, `init` will
drop the system to single user mode in the middle of the reroot process.

Shutdown and reboot have not yet been addressed for the "root on a userland
client" use case and are humorously ungraceful at this time.

## What Next

The example could easily be adapted to use `ggated(8)` and `ggatec(8)` instead
of `nbd-server` and `nbd-client`.

In the future, a userland RBD client for Ceph could take advantage of this same
mechanism to mount FreeBSD's root filesystem from from a cluster backed, thinly
provisioned machine image.
