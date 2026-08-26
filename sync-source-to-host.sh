#!/usr/bin/env bash
# Push a local RTLSDR-Airband source tree to a host running this container and
# rebuild it in place, without an image rebuild or a container registry.
#
# The image ships the RTLSDR-Airband source at /opt/rtlsdr-airband and keeps the
# full toolchain, compiling it on container start.  Bind-mount a local source
# tree over that path and set RTLSDRAIRBAND_BUILD_PLATFORM (which forces a
# recompile on every start) and this script is all the deploy you need:
#
#   volumes:
#     - ./src-rtlsdr-airband:/opt/rtlsdr-airband
#   environment:
#     - RTLSDRAIRBAND_BUILD_PLATFORM=generic
#     # so root's git in the container can read a host-user-owned tree
#     - GIT_CONFIG_COUNT=1
#     - GIT_CONFIG_KEY_0=safe.directory
#     - GIT_CONFIG_VALUE_0=/opt/rtlsdr-airband
#
# Configure by exporting the variables below, or by putting them in an untracked
# sync.env next to this script (see sync.env.example).
#
# The remote build directory lives inside the synced tree and is excluded here,
# which also protects it from --delete, so rebuilds are incremental (~20 s rather
# than ~2 min).  It is owned by root, since the container builds as root; force a
# clean rebuild with:  ssh "$SYNC_HOST" sudo rm -rf "$SYNC_DIR/build"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "${SCRIPT_DIR}/sync.env" ] && . "${SCRIPT_DIR}/sync.env"

: "${SYNC_HOST:?set SYNC_HOST (ssh target running the container)}"
: "${SYNC_DIR:?set SYNC_DIR (absolute path of the source tree on that host)}"
: "${SYNC_SRC:?set SYNC_SRC (local RTLSDR-Airband checkout to push)}"
SYNC_CONTAINER="${SYNC_CONTAINER:-rtlsdrairband}"

echo "==> Syncing ${SYNC_SRC} -> ${SYNC_HOST}:${SYNC_DIR}"
rsync -a --delete \
	--exclude 'builds/' \
	--exclude 'build/' \
	--exclude 'system_tests/.generated_input/' \
	--exclude 'system_tests/test_output/' \
	"${SYNC_SRC%/}/" "${SYNC_HOST}:${SYNC_DIR%/}/"

if [ "${1:-}" = "--no-restart" ]; then
	echo "==> Synced; not restarting (--no-restart)"
	exit 0
fi

echo "==> Restarting ${SYNC_CONTAINER} (recompiles on start)"
ssh "${SYNC_HOST}" "docker restart '${SYNC_CONTAINER}'"

echo "==> Following the build; ctrl-c when you have seen enough"
exec ssh "${SYNC_HOST}" "docker logs -f --since 10s '${SYNC_CONTAINER}'"
