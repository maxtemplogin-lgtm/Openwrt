#!/bin/sh
# Upgrade platform shim for Kenstel KAP-110
#
# The board is not a ubi-based router in the usual sense; it is an AP with a
# single 64 MiB NAND partition (spi0.1, 0x0-0x4000000) holding the rootfs UBI,
# with the kernel inside the same UBI (KERNEL_IN_UBI := 1).
#
# No platform_check/upgrade handlers are required: default_platform.sh handles
# the plain squashfs->sysupgrade path, which is all this board needs.

REQUIRE_IMAGE_SIZE=65536