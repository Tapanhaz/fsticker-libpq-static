
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <postgres-git-tag> <platform-label>" >&2
    exit 1
fi

PG_TAG="$1"
PLATFORM="$2"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${ROOT}/_pg_src"
BUILD_DIR="${ROOT}/_pg_build"
DIST_DIR="${ROOT}/dist"

rm -rf "${SRC_DIR}" "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${DIST_DIR}/include" "${DIST_DIR}/lib"

echo "==> Fetching postgres @ ${PG_TAG}"
git clone -c core.autocrlf=false --branch "${PG_TAG}" --depth 1 \
    https://github.com/postgres/postgres.git "${SRC_DIR}"


MESON_ARGS=(
    setup "${BUILD_DIR}" "${SRC_DIR}"
    --buildtype=release
    -Ddefault_library=static
    -Dssl=none
    -Dgssapi=disabled
    -Dldap=disabled
    -Dpam=disabled
    -Dsystemd=disabled
    -Dselinux=disabled
    -Dbonjour=disabled
    -Dreadline=disabled
    -Dzlib=disabled
    -Dlz4=disabled
    -Dzstd=disabled
    -Dicu=disabled
    -Dllvm=disabled
    -Dnls=disabled
    -Ddocs=disabled
    -Dplperl=disabled
    -Dplpython=disabled
    -Dpltcl=disabled
)

case "${PLATFORM}" in
    windows-*)
        MESON_ARGS+=(--vsenv)
        export PATH="/c/Strawberry/perl/bin:${PATH}"
        ;;
    macos-*)
        export MACOSX_DEPLOYMENT_TARGET=15.4
        ;;
esac

echo "==> meson setup"
meson "${MESON_ARGS[@]}"


echo "==> ninja build (libpq only)"
LIBPQ_TARGETS=(
    "libpq:static_library"
    "pgcommon_shlib:static_library"
    "pgport_shlib:static_library"
case "${PLATFORM}" in
    windows-*)
        meson compile -C "${BUILD_DIR}" "${LIBPQ_TARGETS[@]}"
        ;;
    *)
        meson compile -C "${BUILD_DIR}" "${LIBPQ_TARGETS[@]}"
        ;;
esac

echo "==> collecting static library"
for pair in \
    "src/interfaces/libpq:libpq.a" \
    "src/common:libpgcommon.a" \
    "src/port:libpgport.a"
do
    subdir="${pair%%:*}"
    libname="${pair##*:}"
    LIB_SRC=$(find "${BUILD_DIR}/${subdir}" -maxdepth 1 -name "${libname}" | head -n1)
    if [[ -z "${LIB_SRC}" || ! -f "${LIB_SRC}" ]]; then
        echo "ERROR: could not locate ${libname} under ${BUILD_DIR}/${subdir}" >&2
        exit 1
    fi
    cp "${LIB_SRC}" "${DIST_DIR}/lib/${libname}"
done

echo "==> collecting headers"
cp "${SRC_DIR}/src/interfaces/libpq/libpq-fe.h"        "${DIST_DIR}/include/"
cp "${SRC_DIR}/src/include/postgres_ext.h"              "${DIST_DIR}/include/"
cp "${BUILD_DIR}/src/include/pg_config_ext.h"            "${DIST_DIR}/include/"

echo "==> done: ${DIST_DIR}"
find "${DIST_DIR}" -type f -print