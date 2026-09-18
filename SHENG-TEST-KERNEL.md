# Sheng 7.2.6 test kernel

Base: ianchb/sm8550-mainline, `sheng-7.2.6`, commit
`42f3b40c702abbc37c3a04c95af008cd283aeaf3`.

## Changes

- Disable `ADRENO_QUIRK_IFPC` only in the A740 (`0x43050a01`) entry.
  The old flag is kept in a comment. No new parameters or runtime switches.
- Add Iris HFI gen2 decode-order output controls, based on
  [Radxa 3934e935](https://github.com/radxa/kernel/commit/3934e935b9e4803ac5d05711920b8e0c2998ae10).
  Userspace must explicitly enable zero display delay before streaming.
- Allow up to 64 HFI gen2 decoder CAPTURE buffers, based on
  [Radxa's companion patch](https://github.com/radxa-pkg/libva-v4l2/blob/master/patches/0002-media-iris-allow-larger-capture-buffer-pools-on-HFI-.patch).
  The minimum allocation and encoder queues are unchanged.

The Iris changes originate from Xilin Wu's GPL-licensed patches. This build
does not include encoder deblocking changes or a VA-API userspace driver.
The experimental [libva-v4l2 backend](https://github.com/radxa-pkg/libva-v4l2)
is a separate userspace component; its published hardware validation targets
SC8280XP, so SM8550 decoding still needs device testing.

## Build

On an ARM64 Ubuntu host, install the dependencies listed in
`.github/workflows/sheng-kernel.yml`, then run:

```sh
bash scripts/build-sheng.sh
```

The script uses the upstream `defconfig` plus `sm8550.config`. For an x86-64
Linux host, also install `gcc-aarch64-linux-gnu` and
`binutils-aarch64-linux-gnu`, and export `CROSS_COMPILE=aarch64-linux-gnu-`.
GitHub Actions uses the native ARM64 runner and uploads the outputs as an
artifact without publishing a release.

The script fetches AOSP's complete mkbootimg at pinned commit
`d2bb0af5ba6d3198a3e99529c97eda1be0b5a093`, including its Python modules.
Build logs are uploaded separately, even when compilation or packaging fails.

Outputs are in `out/artifacts/`: the dual-boot image (`root=PARTLABEL=linux`),
matching `linux-xiaomi-sheng.deb`, configuration, build provenance and hashes.
The script only builds files; it does not flash or install them.

## Device validation

Install matching modules and retain the previous working kernel before boot
testing. Confirm `uname -r` ends with `-sheng-ifpc-off-iris`. Check GPU/GMU logs,
graphics workloads and suspend/resume; disabling IFPC may increase power use.
An improvement after upgrading alone does not prove IFPC caused the faults.
For that comparison, rebuild the same source with only the A740 flag restored.

With a compatible userspace backend installed, check `vainfo` and exercise
VA-API decoding using known H.264/HEVC/VP9 test videos, including B frames.
Kernel compilation alone cannot establish successful hardware decoding.
