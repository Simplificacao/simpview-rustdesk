# SIMP View: build de RELEASE do binario headless (--features cli,linux-pkg-config)
# para rodar no servidor Oracle, dentro de um container debian:bookworm-slim
# (mesma familia glibc do build -- por isso NAO precisa casar com o Ubuntu 22.04
# do host: o binario roda DENTRO de um container isolado, nao direto no host).
#
# Uso: docker run --rm -v "$PWD":/src -v simpview_cargo_cache:/usr/local/cargo -w /src \
#        rust:1.82-bookworm bash simpview-build/headless-linux-release-build.sh
set -e
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  build-essential pkg-config git clang libclang-dev perl \
  libgtk-3-dev libpulse-dev libdbus-1-dev libpam0g-dev \
  libxcb1-dev libxcb-randr0-dev libx11-dev libxi-dev libxtst-dev libxrandr-dev libxdo-dev \
  libasound2-dev libglib2.0-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libopus-dev libyuv-dev libvpx-dev libaom-dev > /tmp/apt.log 2>&1 || (tail -150 /tmp/apt.log; exit 1)
echo "=== APT_OK ==="

mkdir -p /usr/lib/x86_64-linux-gnu/pkgconfig
cat > /usr/lib/x86_64-linux-gnu/pkgconfig/libyuv.pc <<'PC'
prefix=/usr
libdir=${prefix}/lib/x86_64-linux-gnu
includedir=${prefix}/include

Name: libyuv
Description: YUV scaling and conversion library
Version: 1857
Libs: -L${libdir} -lyuv
Cflags: -I${includedir}
PC
echo "=== LIBYUV_PC_OK ==="

if ! grep -q "fn set_permanent_password_forced" libs/hbb_common/src/config.rs; then
  git -C libs/hbb_common apply --verbose --ignore-whitespace \
    "$(pwd)/simpview-patches/0001-hbb_common-forced-permanent-password.patch"
fi

cd /src
cargo build --release --bin rustdesk --features cli,linux-pkg-config --no-default-features 2>&1 | tail -400
code=${PIPESTATUS[0]}
echo "=== CARGO_BUILD_EXIT=${code} ==="
if [ "$code" != "0" ]; then
  exit $code
fi

echo "=== BINARIO ==="
ls -la target/release/rustdesk
file target/release/rustdesk
echo "=== LDD (dependencias dinamicas) ==="
ldd target/release/rustdesk
