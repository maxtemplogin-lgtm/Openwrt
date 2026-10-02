# Kenstel KAP-110 dual-band indoor access point
#
# SoC:    Qualcomm IPQ4018 (quad Cortex-A7 @717MHz, integrated 2x2 DBDC 802.11ac)
# RAM:    256 MiB DDR3
# NAND:   GigaDevice GD5F1GQ1UC, 128 MiB, SLC, page size 2048, OOB 128
# NOR:    GD25Q16 2 MiB (spi0.0) - holds SBL1/MIBIB/QSEE/CDT/DDRPARAMS/APPSBLENV/APPSBL/ART
# rootfs: spi0.1, 0x00000000-0x00400000 (64 MiB), UBI
#
# The board boots the AP-DK01.1-C2 reference design, so we reuse the upstream
# DK01 FIT configuration rather than shipping a private DTS. Only the board
# identity, image size and packages differ from the reference profile.
#
# NOTE: rootfs here is 64 MiB, twice the 32768k used by qcom_ap-dk01.1-c1.

define Device/kenstel_kap110
    $(call Device/Default)
    $(call Device/FitzImage)
    $(call Device/UbiFit)
    DEVICE_VENDOR := Kenstel
    DEVICE_MODEL := KAP-110
    DEVICE_TITLE := Kenstel KAP-110 (IPQ4018) dual-band AP
    DEVICE_PACKAGES := kmod-usb-acm
    SOC := qcom-ipq4018
    DEVICE_DTS_CONFIG := config@ap.dk01.1-c2
    BLOCKSIZE := 128k
    PAGESIZE := 2048
    IMAGE_SIZE := 65536k
    FILESYSTEMS := squashfs
    KERNEL_IN_UBI := 1
    UBINIZE_OPTS := -E 5
    IMAGES := factory.ubi sysupgrade.bin
    IMAGE/factory.ubi := append-ubi | pad-to 2048
    IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef

TARGET_DEVICES += kenstel_kap110