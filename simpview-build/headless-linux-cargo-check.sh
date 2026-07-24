# SIMP View: valida que o fork compila em modo headless (--features cli,linux-pkg-config)
# para Linux. Usado pelo binario que roda no gateway/servidor e abre --port-forward
# para o acesso via RDP/TS centralizado no painel (sem GUI, sem stdin/TTY).
#
# Uso: docker run --rm -v "$PWD":/src -v simpview_cargo_cache:/usr/local/cargo -w /src \
#        rust:1.82-bookworm bash simpview-build/headless-linux-cargo-check.sh
#
# O volume simpview_cargo_cache (mapeado em /usr/local/cargo) e opcional mas recomendado:
# sem ele, cada execucao rebaixa do zero as dependencias git grandes (wezterm, harfbuzz).
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

# Debian nao empacota libyuv.pc (so headers + .a/.so) -- gerar na mao pro pkg-config achar.
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

# O patch da senha permanente forcada normalmente so e aplicado no CI Windows
# (build-simplificacao-windows.yml). Fora dali (build local/Linux) precisa aplicar
# manualmente no submodulo, senao ipc.rs nao compila (set_permanent_password_forced ausente).
if ! grep -q "fn set_permanent_password_forced" libs/hbb_common/src/config.rs; then
  git -C libs/hbb_common apply --verbose --ignore-whitespace \
    "$(pwd)/simpview-patches/0001-hbb_common-forced-permanent-password.patch"
fi

cd /src
cargo check --bin rustdesk --features cli,linux-pkg-config --no-default-features 2>&1 | tail -400
code=${PIPESTATUS[0]}
echo "=== CARGO_CHECK_EXIT=${code} ==="
exit $code
