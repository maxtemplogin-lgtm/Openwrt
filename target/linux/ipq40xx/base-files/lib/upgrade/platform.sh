#!/bin/sh
# Upgrade handling for the Kenstel KAP-110.
#
# WHY THIS FILE MATTERS:
# `platform_check` returning 0 is what tells the sysupgrade machinery that this
# board is supported. Without it (or without a matching case), LuCI refuses the
# image with:
#     Image check failed: Firmware upgrade is not implemented for this platform.
# and the CLI `sysupgrade` aborts the same way. Both must be defined together -
# platform_check to authorise, platform_do_upgrade to perform the write.
#
# Layout: single 64 MiB NAND partition (spi0.1, 0x0-0x4000000) holding a UBI
# image with the kernel inside it (KERNEL_IN_UBI := 1), so default_do_upgrade
# handles it with no vendor-specific steps.

REQUIRE_IMAGE_SIZE=65536

platform_check() {
	local board="$(board_name)"

	case "$board" in
		kenstel,kap110)
			return 0
			;;
	esac

	return 1
}

platform_do_upgrade() {
	local board="$(board_name)"

	case "$board" in
		kenstel,kap110)
			default_do_upgrade "$1"
			;;
	esac
}
