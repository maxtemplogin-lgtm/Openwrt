# Kenstel KAP-110 → OpenWrt build

Custom OpenWrt **25.12.5** image for the Kenstel KAP-110 dual-band access point
(Qualcomm IPQ4018). Built with GitHub Actions — no local build environment needed.

## How to build

1. Push this repo to GitHub.
2. Open the **Actions** tab → **Build KAP-110 firmware** → **Run workflow**.
3. Download the `openwrt-kenstel-kap110` artifact when it finishes.

It also builds automatically when you change anything under `target/linux/ipq40xx/`.

First run takes roughly **1.5–3 hours**. Subsequent runs are much faster — the
source download and ccache are both cached.

## Which image to flash

**Flash `initramfs-fit-uImage.itb` first.** It boots entirely from RAM and writes
nothing to flash, so a wrong device tree costs you only a power cycle.

Copy it to a FAT32-formatted USB stick, insert it into the AP, and power on while
holding the reset button. Once it reaches a shell, flash the real image:

**`squashfs-sysupgrade.bin`** — normal upgrade path, preserves settings.

## Hardware this targets

| | |
|---|---|
| SoC | Qualcomm IPQ4018 — quad Cortex-A7 @ 717 MHz |
| RAM | 256 MiB DDR3 |
| NAND | GigaDevice GD5F1GQ1UC, 128 MiB, SLC, **page size 2048** |
| NOR | GD25Q16 2 MiB — SBL1/MIBIB/QSEE/CDT/DDRPARAMS/APPSBLENV/APPSBL/ART |
| rootfs | `spi0.1`, **64 MiB**, UBI (PEB 128K, LEB 124K) |
| Wi-Fi | 2× integrated AHB ath10k (2.4 GHz + 5 GHz) |
| Bootloader | U-Boot 2012.07, FIT image, kernel load `0x80208000` |

### Why no device tree

The stock firmware boots the AP reference design:

```
Using 'config@ap.dk01.1-c2' configuration
  Description: ARM OpenWrt qcom-ipq40xx-ap.dkxx device tree blob
```

So the profile reuses that FIT config via `DEVICE_DTS_CONFIG := config@ap.dk01.1-c2`
instead of shipping a private DTS. Shipping devices like the GL.iNet GL-A1300
use the same config. Upstream's `ipq40xx` target defaults
`KERNEL_LOADADDR := 0x80208000`, matching this board exactly.

## Files in this repo

```
target/linux/ipq40xx/image/kenstel-kap110.mk              device profile
target/linux/ipq40xx/base-files/etc/board.d/01_leds       no LEDs claimed
target/linux/ipq40xx/base-files/etc/board.d/02_network    VLAN/bridge topology
target/linux/ipq40xx/base-files/etc/uci-defaults/99-kenstel-kap110
target/linux/ipq40xx/base-files/etc/hotplug.d/firmware/10-ath10k-caldata
target/linux/ipq40xx/base-files/lib/upgrade/platform.sh
```

## The three values that decide whether it works

1. **`IMAGE_SIZE := 65536k`** — this board's rootfs is 64 MiB. The upstream DK01
   profile uses `32768k`; copying it verbatim makes sysupgrade fail.
2. **`PAGESIZE := 2048`** — from the boot log. A 4096 mismatch breaks UBI attach.
3. **`DEVICE_DTS_CONFIG`, not `DEVICE_DTS`** — the FIT config name differs from
   the DTS filename.

## Per-unit MAC configuration

MAC addresses are **not** in ART (`eth0/eth1 MAC Address from ART is not valid`).
They form a contiguous block with the device serial in the last octet:

| Interface | MAC | Offset |
|---|---|---|
| wifi1 (5 GHz) | `68:33:2c:00:48:28` | base+0 |
| wifi0 (2.4 GHz) | `68:33:2c:00:48:29` | base+1 |
| eth0 | `68:33:2c:00:48:2a` | base+2 |
| eth1 | `68:33:2c:00:48:2b` | base+3 |

Edit `BASE_MAC` in `etc/uci-defaults/99-kenstel-kap110` per unit — it derives the
other three. The board label carries the base MAC.

## Network topology

Reproduced from the stock boot log. This is a VLAN-tagged enterprise AP, not a router:

```
br-lan      <- eth1.10   VLAN 10   client/traffic LAN
br-apman    <- eth1.20   VLAN 20   cloud-managed AP network
br-brman    <- eth1.60   VLAN 60   backhaul / mesh
br-localman <- eth1      untagged native local management (holds 192.168.1.1)
```

All four are in one L2 bridge. **There is no WAN port and no NAT.**

To simplify to a single plain LAN, replace the `ucidef_set_interfaces_lan_wan`
line in `02_network` with:
```sh
ucidef_set_interface lan bridge "eth1.10" eth1
```

## Known issues

**Calibration data.** The stock firmware writes `/tmp/wifi0.caldata` and
`/tmp/wifi1.caldata` (12064 bytes each) before ath10k probes. `10-ath10k-caldata`
restores them from the overlay. If the overlay is wiped they are gone and you need
a stock unit to dump them again — **save them while you have one**:
```bash
scp root@192.168.1.1:/tmp/wifi0.caldata root@192.168.1.1:/tmp/wifi1.caldata .
```
Without caldata the radios appear in `iw phy` but never associate.

**Regulatory domain.** Stock reports `EEPROM regdomain 0x0` — no valid country
code is programmed. The uci-defaults script sets `country='US'`; **change this to
your actual country**.

**One bad NAND eraseblock** (`Bad eraseblock 1023`, and UBI warns it cannot
reserve enough PEBs for bad-block handling). Harmless with a small image, but it
is why an image may occasionally fail to fit.

**NSS is present but disabled** in stock firmware (`nss is not enabled on this
platform`). Leave it off — upstream ipq40xx uses DSA.

## Verifying a successful flash

```bash
logread | grep -i cal              # both caldata loads succeed
iw phy                             # 2 radios present
wifi status                        # both up
ip -br addr                        # br-lan, br-apman, br-brman, br-localman
logread | grep -i kap110           # MAC assignment messages
```