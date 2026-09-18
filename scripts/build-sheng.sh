#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail

cd "$(dirname "$0")/.."
export ARCH=arm64 LOCALVERSION=
out="$PWD/out"
artifacts="$out/artifacts"
pkg="$out/package-root"
mkbootimg_revision=d2bb0af5ba6d3198a3e99529c97eda1be0b5a093

git init -q "$out/mkbootimg"
git -C "$out/mkbootimg" fetch --depth=1 \
    https://android.googlesource.com/platform/system/tools/mkbootimg "$mkbootimg_revision"
git -C "$out/mkbootimg" checkout --detach FETCH_HEAD
python3 "$out/mkbootimg/mkbootimg.py" --help > /dev/null

make O="$out" defconfig sm8550.config
scripts/config --file "$out/.config" \
    --set-str LOCALVERSION '-sheng-ifpc-off-iris' \
    --disable LOCALVERSION_AUTO
make O="$out" olddefconfig
make O="$out" -j"$(nproc)" Image.gz qcom/sm8550-xiaomi-sheng.dtb modules
release=$(make O="$out" -s kernelrelease)

mkdir -p "$artifacts" "$pkg/DEBIAN" "$pkg/boot"
make O="$out" INSTALL_MOD_PATH="$pkg/usr" INSTALL_MOD_STRIP=1 modules_install
rm -f "$pkg/usr/lib/modules/$release/build" "$pkg/usr/lib/modules/$release/source"

install -m644 "$out/arch/arm64/boot/Image.gz" "$pkg/boot/"
install -m644 "$out/arch/arm64/boot/dts/qcom/sm8550-xiaomi-sheng.dtb" "$pkg/boot/"
install -m644 "$out/.config" "$pkg/boot/config-$release"
install -m644 "$out/System.map" "$pkg/boot/System.map-$release"
cat "$pkg/boot/Image.gz" "$pkg/boot/sm8550-xiaomi-sheng.dtb" > "$pkg/boot/Image.gz-dtb_sheng"

python3 "$out/mkbootimg/mkbootimg.py" --kernel "$pkg/boot/Image.gz-dtb_sheng" \
    --cmdline 'root=PARTLABEL=linux' --header_version 0 \
    --base 0x00000000 --kernel_offset 0x00008000 \
    --tags_offset 0x01e00000 --pagesize 4096 \
    -o "$artifacts/boot_sheng_dualboot_$release.img"

cat > "$pkg/DEBIAN/control" <<EOF
Package: linux-xiaomi-sheng
Version: $release
Architecture: arm64
Maintainer: EmberLuo
Section: kernel
Priority: optional
Description: Xiaomi sheng kernel with A740 IFPC disabled and Iris decode patches
EOF
dpkg-deb --build --root-owner-group "$pkg" "$artifacts/linux-xiaomi-sheng.deb"
install -m644 "$out/.config" "$artifacts/config-$release"
git diff 42f3b40c702abbc37c3a04c95af008cd283aeaf3 -- \
    drivers/gpu/drm/msm/adreno/a6xx_catalog.c drivers/media/platform/qcom/iris \
    > "$artifacts/kernel.patch"
{
    printf 'kernel_release=%s\n' "$release"
    printf 'source_commit=%s\n' "$(git rev-parse HEAD)"
    printf 'source_base=42f3b40c702abbc37c3a04c95af008cd283aeaf3\n'
    printf 'mkbootimg_commit=%s\n' "$mkbootimg_revision"
    "${CROSS_COMPILE:-}gcc" --version | head -n 1
} > "$artifacts/build-info.txt"
cd "$artifacts"
sha256sum ./*.img ./*.deb config-* build-info.txt kernel.patch > SHA256SUMS
