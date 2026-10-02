# HANDOFF — Kenstel KAP-110 OpenWrt port

**Status: everything prepared, nothing compiled yet.** Waiting on GitHub push.

## Where things are

| What | Path |
|---|---|
| Ready-to-push repo | `C:\Users\Max\AppData\Local\hermes\cache\scratch\repo` |
| Repo as zip | `C:\Users\Max\AppData\Local\hermes\cache\scratch\KAP110-openwrt-repo.zip` |
| Original device profile | `C:\Users\Max\AppData\Local\hermes\cache\scratch\kap110` |
| Device profile as zip | `C:\Users\Max\AppData\Local\hermes\cache\scratch\kap110-kenstel-openwrt-profile.zip` |
| Boot log (user-supplied) | `D:\New Share\kenstel chip\` + pasted in conversation |
| Skill reference | OpenWrt skill → `references/adding-a-device.md` |
| Board photos | `D:\New Share\kenstel chip\IMG_20261002_2233{01_043,51}.jpg` |

## Resume in one step

```bash
cd C:\Users\Max\AppData\Local\hermes\cache\scratch\repo
git init && git add -A && git commit -m "Kenstel KAP-110 OpenWrt 25.12.5 device profile + CI build"
git remote add origin https://github.com/maxtemplogin-lgtm/Openwrt.git
git push -u origin main
```

Then: GitHub → **Actions** → **Build KAP-110 firmware** → **Run workflow**.
Artifact: `openwert-kenstel-kap110` (spelled `openwrt-kenstel-kap110`).
First build ~1.5–3 h; later runs much faster (ccache + dl cache).

## Hardware — confirmed from boot log, not datasheets

| | |
|---|---|
| SoC | **Qualcomm IPQ4018**, quad Cortex-A7 @717 MHz |
| RAM | 256 MiB DDR3 (~236 MiB available to kernel) |
| NAND | GigaDevice GD5F1GQ1UC, 128 MiB, **SLC, page size 2048**, OOB 128 |
| NOR | GD25Q16 2 MiB `spi0.0`: SBL1/MIBIB/QSEE/CDT/DDRPARAMS/APPSBLENV/APPSBL/**ART** |
| rootfs | `spi0.1`, `0x0–0x4000000` = **64 MiB**, UBI (PEB 128K, LEB 124K, sub-page 2048) |
| Wi-Fi | 2× integrated AHB ath10k: `a000000.wifi` (2.4 GHz), `a800000.wifi` (5 GHz) |
| Board data | `boardData_1_0_IPQ4019_Y9803_wifi{0,1}.bin`, FW `IPQ4019/hw.1/athwlan.bin` |
| Bootloader | U-Boot 2012.07 (Chaos Calmer 15.05.1), FIT, kernel load `0x80208000` |
| Switch | ess-switch/psgmii, PHY `0x4dd0b2`, chip ver `0x1401`; **CPU port is `eth1`** |

## Why no DTS is needed

```
Using 'config@ap.dk01.1-c2' configuration
  Description: ARM OpenWrt qcom-ipq40xx-ap.dkxx device tree blob
```

Stock firmware boots the AP-DK01.1-C2 reference design. Profile reuses it via
`DEVICE_DTS_CONFIG := config@ap.dk01.1-c2`. Verified against upstream 25.12.5:
shipping devices (GL.iNet GL-A1300, GL-AP1300) use the same config, and
`target/linux/ipq40xx/image/Makefile` sets `KERNEL_LOADADDR := 0x80208000` —
matching this board exactly.

## The three values that decide success

1. `IMAGE_SIZE := 65536k` — rootfs is 64 MiB. Upstream DK01 uses `32768k`; wrong
   value = sysupgrade fails / writes past partition. **Most likely thing to fix.**
2. `PAGESIZE := 2048` — from `nand: … page size: 2048`. A 4096 mismatch = UBI
   attach failure at boot.
3. `DEVICE_DTS_CONFIG`, not `DEVICE_DTS`.

## MAC layout — SOLVED

Not in ART (`eth0/eth1 MAC Address from ART is not valid` in boot log).
Contiguous block, device serial in last octet, `68:33:2c` = ODM/EMS prefix:

| Interface | MAC | Offset |
|---|---|---|
| wifi1 (5 GHz) | `68:33:2c:00:48:28` | base+0 |
| wifi0 (2.4 GHz) | `68:33:2c:00:48:29` | base+1 |
| eth0 | `68:33:2c:00:48:2a` | base+2 |
| eth1 | `68:33:2c:00:48:2b` | base+3 (holds 192.168.1.1) |

Derivation logic verified against live values — all four reproduce exactly.
**Per-unit:** edit `BASE_MAC` in `etc/uci-defaults/99-kenstel-kap110`. Label
carries it.

## Network topology

```
br-lan      <- eth1.10   VLAN 10   client LAN
br-apman    <- eth1.20   VLAN 20   cloud-managed AP
br-brman    <- eth1.60   VLAN 60   backhaul/mesh
br-localman <- eth1      untagged  native mgmt (192.168.1.1)
```

All in one L2 bridge. **No WAN port, no NAT — this is an AP, not a router.**

## Outstanding risks

**1. caldata — time-sensitive.** Stock writes `/tmp/wifi0.caldata` and
`/tmp/wifi1.caldata` (12064 B each, checksums `0x21b3` / `0xe1c9`). `/tmp` is
tmpfs → gone on reboot. If overlay wiped, gone permanently without another stock
unit. Still not saved.
```bash
scp root@192.168.1.1:/tmp/wifi0.caldata root@192.168.1.1:/tmp/wifi1.caldata .
```

**2. Regulatory domain.** Stock: `isCountryCodeValid: EEPROM regdomain 0x0`.
Script sets `country='US'` — must change to real country.

**3. Bad NAND block.** `Bad eraseblock 1023`; UBI warns
`cannot reserve enough PEBs for bad PEB handling, reserved 5, need 20`. Benign,
but explains a possible image-fit failure.

**4. Nothing compiled.** Every value derived from boot log + `ip addr`. First
build is the real test.

**5. Chip marking never legibly read.** Vision hallucinated ("MediaTek MT7620A").
`Winbond W632GU6MB-12` confirmed DDR3 x16 1.35V. SoC identified via
`Machine model:` line and vendor specs, not the package marking.

## First-flash procedure

Flash **`initramfs-fit-uImage.itb`** first — boots from RAM, writes nothing to
flash. FAT32 USB stick, insert, power on while holding reset.

Then verify:
```bash
logread | grep -i cal      # both caldata loads
iw phy                     # 2 radios
ip -br addr                # br-lan, br-apman, br-brman, br-localman
logread | grep -i kap110   # MAC messages
```

## Errors already made and corrected (don't repeat)

- Invented `ipq-wifi-ipq4018-kenstel-kap110` in `DEVICE_PACKAGES`. `ipq-wifi`
  packages are auto-generated from a board list; **IPQ4019 is not in it.** Would
  have failed the build. Removed.
- First caldata script used `case "$1" = firmware`; `hotplug.d/firmware` actually
  receives `$2=firmware`. Fixed.
- First `02_network` declared a lan/wan pair on a device with no WAN and orphaned
  three interfaces; also called `board_cancel_upgrade`, which doesn't belong
  there. Rewritten as one `ucidef_set_interfaces_lan_wan bridge lan`.

## Machine constraints (why CI, not local)

No WSL, no Docker, no admin rights on this Windows host → cannot build locally.
No `gh`, no git identity, no stored credentials → could not push either. CI is
the only route until Git Desktop is installed and authenticated.