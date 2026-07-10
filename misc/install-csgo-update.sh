#!/bin/bash
# 중앙 CS:GO 게임 파일 배포 데몬을 wings 노드에 설치한다 (멱등)
#
# 하는 일
#   1. 저장소를 /opt/cs2kr/csgo-egg 에 두고
#   2. /usr/local/bin/update-csgo-centralized.sh 를 거기로 심볼릭 링크하고
#   3. csgo-vpk-daemon.service 를 등록·기동한다
#
# 사용법: sudo bash misc/install-csgo-update.sh
#
# 게임 파일(/srv/csgo-shared) 자체는 이 스크립트가 내려받지 않는다.
# CS:GO 는 서비스가 종료돼 업데이트가 없으므로 cron 도 걸지 않는다.

set -euo pipefail

REPO_DIR="/opt/cs2kr/csgo-egg"
SCRIPT_NAME="update-csgo-centralized.sh"
TARGET="/usr/local/bin/${SCRIPT_NAME}"
UNIT="/etc/systemd/system/csgo-vpk-daemon.service"
CSGO_DIR="/srv/csgo-shared"

ok()   { echo "  ✓ $*"; }
warn() { echo "  ! $*" >&2; }
die()  { echo "  ✗ $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "root 로 실행하십시오 (sudo)"

# ── 1. 의존성 ────────────────────────────────────────────────────────────────
# nsenter 는 CSGO_DIR 을 컨테이너 마운트 네임스페이스에 꽂는 데 쓴다 (symlink 방식).
for cmd in docker rsync curl python3 nsenter; do
    command -v "$cmd" >/dev/null 2>&1 || die "필요한 명령이 없습니다: $cmd"
done
ok "의존성 확인"

# ── 2. 스크립트 배치 ─────────────────────────────────────────────────────────
# 저장소 안에서 실행했으면 그 파일을, 아니면 GitHub 에서 받는다.
#
# `curl ... | sudo bash` 로 실행하면 BASH_SOURCE 가 비어 있다.
# set -u 아래에서는 그대로 참조하면 unbound variable 로 죽는다. :- 로 받아야 한다.
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${SCRIPT_NAME}"
fi
mkdir -p "${REPO_DIR}/misc"

if [ -n "$SRC" ] && [ -f "$SRC" ] && [ "$SRC" != "${REPO_DIR}/misc/${SCRIPT_NAME}" ]; then
    # 저장소를 clone 해 그 안에서 실행한 경우
    install -o root -g root -m 755 "$SRC" "${REPO_DIR}/misc/${SCRIPT_NAME}"
    ok "스크립트 배치: ${REPO_DIR}/misc/${SCRIPT_NAME}"
else
    # curl | bash 로 실행한 경우. 항상 최신본을 받아 갱신한다.
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    curl -fsSL "https://raw.githubusercontent.com/CS2KR/csgo-egg/main/misc/${SCRIPT_NAME}" \
        -o "$tmp" || die "스크립트를 내려받지 못했습니다"
    bash -n "$tmp" || die "내려받은 스크립트에 문법 오류가 있습니다"

    if [ -f "${REPO_DIR}/misc/${SCRIPT_NAME}" ] && cmp -s "$tmp" "${REPO_DIR}/misc/${SCRIPT_NAME}"; then
        ok "스크립트가 이미 최신입니다"
    else
        # 스크립트 상단 CONFIG 블록은 운영자가 고치는 곳이다. 덮기 전에 남긴다.
        if [ -f "${REPO_DIR}/misc/${SCRIPT_NAME}" ]; then
            cp -a "${REPO_DIR}/misc/${SCRIPT_NAME}" \
                  "${REPO_DIR}/misc/${SCRIPT_NAME}.bak-$(date +%Y%m%d%H%M%S)"
            warn "기존 스크립트를 백업했습니다. CONFIG 를 고쳤다면 옮겨 적으십시오"
        fi
        install -o root -g root -m 755 "$tmp" "${REPO_DIR}/misc/${SCRIPT_NAME}"
        ok "스크립트 갱신됨"
    fi
fi

bash -n "${REPO_DIR}/misc/${SCRIPT_NAME}" || die "스크립트 문법 오류"

# ── 3. 심볼릭 링크 ───────────────────────────────────────────────────────────
# 기존 실파일이 있으면 백업한다. 덮어쓰지 않는다.
if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    backup="${TARGET}.bak-$(date +%Y%m%d%H%M%S)"
    mv "$TARGET" "$backup"
    warn "기존 파일을 ${backup} 로 옮겼습니다"
fi
ln -sfn "${REPO_DIR}/misc/${SCRIPT_NAME}" "$TARGET"
ok "심볼릭 링크: $TARGET → $(readlink "$TARGET")"

# ── 4. 게임 파일 확인 ────────────────────────────────────────────────────────
if [ ! -d "$CSGO_DIR" ]; then
    warn "${CSGO_DIR} 이 없습니다. SteamCMD 로 appid 740 을 먼저 받으십시오."
    warn "  steamcmd +force_install_dir ${CSGO_DIR} +login anonymous +app_update 740 +quit"
else
    ok "게임 파일: ${CSGO_DIR} ($(du -sh "$CSGO_DIR" 2>/dev/null | cut -f1))"
fi

# ── 5. systemd ───────────────────────────────────────────────────────────────
cat > "$UNIT" <<'UNITEOF'
[Unit]
Description=CSGO VPK Push Daemon
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/update-csgo-centralized.sh --daemon
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=csgo-vpk-daemon

[Install]
WantedBy=multi-user.target
UNITEOF

systemctl daemon-reload
systemctl enable csgo-vpk-daemon >/dev/null 2>&1
systemctl restart csgo-vpk-daemon
sleep 2

if systemctl is-active --quiet csgo-vpk-daemon; then
    ok "데몬 기동됨"
else
    die "데몬이 뜨지 않았습니다. journalctl -u csgo-vpk-daemon -n 30"
fi

echo
echo "  설치 완료. 데몬은 컨테이너 start 이벤트만 감시합니다."
echo "  이미 돌고 있는 게임 서버는 재시작되지 않습니다."
echo
echo "    상태 확인   systemctl status csgo-vpk-daemon"
echo "    로그        journalctl -u csgo-vpk-daemon -f"
echo "    감시 이미지 grep '^SERVER_IMAGE=' ${REPO_DIR}/misc/${SCRIPT_NAME}"
