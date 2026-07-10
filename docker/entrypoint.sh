#!/bin/bash
# CS:GO 서버 컨테이너 진입점 — 중앙 파일 대기 → 정리 → MM/SM·필수 플러그인 설치 → srcds 실행

# 데몬이 이번 부팅에 남길 마커. 지난 부팅의 잔재를 먼저 지운다.
rm -f /home/container/egg/.daemon-managed 2>/dev/null || true

source /utils/logging.sh
source /scripts/cleanup.sh
source /scripts/updaters/alliedmods.sh
source /scripts/updaters/required-plugins.sh

cd /home/container || exit 1
init_egg_directories

GAME_DIR="/home/container/csgo"
TEMP_DIR="/home/container/egg/tmp"
DEFAULTS_DIR="/defaults"

# ---- 1. 중앙 파일 대기 -------------------------------------------------------
# csgo-vpk-daemon 이 vpk 심볼릭 링크와 엔진 파일을 넣어주고 마커를 남긴다.
# egg 41 은 이 루프를 base64 로 인코딩해 startup 문자열에 넣었다. 여기선 그럴 이유가 없다.
wait_for_daemon() {
    local timeout="${DAEMON_WAIT_SECONDS:-15}" count=0
    while [ ! -f /home/container/egg/.daemon-managed ] && [ "$count" -lt "$timeout" ]; do
        sleep 1
        count=$((count + 1))
    done
    if [ -f /home/container/egg/.daemon-managed ]; then
        log_message "중앙 CS:GO 파일 준비 완료" "success"
    else
        log_message "데몬 타임아웃 (${timeout}s). 볼륨의 로컬 파일로 진행한다" "warning"
    fi
}
wait_for_daemon

# ---- 2. 설정 파일 시딩 -------------------------------------------------------
# 없을 때만 놓는다. 패널에서 고친 값을 덮지 않기 위해서다.
seed_config() {
    local name="$1"
    if [ ! -f "${EGG_CONFIGS_DIR}/${name}" ] && [ -f "${DEFAULTS_DIR}/${name}" ]; then
        cp "${DEFAULTS_DIR}/${name}" "${EGG_CONFIGS_DIR}/${name}"
        log_message "기본 설정 생성: ${name}" "info"
    fi
}
seed_config cleanup.json
seed_config required-plugins.json

# ---- 3. 디스크 정리 ----------------------------------------------------------
if [ "${CLEANUP_ENABLED:-1}" -eq 1 ]; then
    cleanup
fi

# ---- 4. MetaMod / SourceMod --------------------------------------------------
# 버전 고정이 기본. SM_VERSION / MM_VERSION 이 비면 브랜치 최신을 따라간다.
install_alliedmods() {
    local tb

    tb=$(resolve_tarball mmsource "${MM_BRANCH:-1.12}" "${MM_VERSION:-}")
    if [ -n "$tb" ] && fetch_and_extract mmsource "${MM_BRANCH:-1.12}" "$tb" "${TEMP_DIR}/mm"; then
        install_metamod_tree "${TEMP_DIR}/mm" "$GAME_DIR" && log_message "MetaMod: $tb" "success"
    else
        log_message "MetaMod 설치 실패" "error"
    fi

    tb=$(resolve_tarball sourcemod "${SM_BRANCH:-1.12}" "${SM_VERSION:-}")
    if [ -n "$tb" ] && fetch_and_extract sourcemod "${SM_BRANCH:-1.12}" "$tb" "${TEMP_DIR}/sm"; then
        install_sourcemod_tree "${TEMP_DIR}/sm" "$GAME_DIR" && log_message "SourceMod: $tb" "success"
    else
        log_message "SourceMod 설치 실패" "error"
    fi

    rm -rf "${TEMP_DIR}/mm" "${TEMP_DIR}/sm"
}

if [ "${MOD_AUTO_INSTALL:-1}" -eq 1 ]; then
    install_alliedmods
fi

# ---- 5. 필수 플러그인 --------------------------------------------------------
if [ "${REQUIRED_PLUGINS_ENABLED:-1}" -eq 1 ]; then
    install_required_plugins "${EGG_CONFIGS_DIR}/required-plugins.json" "$GAME_DIR" "${TEMP_DIR}/plugins" \
        || log_message "필수 플러그인 설치 실패 — 서버는 그대로 띄운다" "error"
    rm -rf "${TEMP_DIR}/plugins"
fi

# ---- 6. 서버 실행 ------------------------------------------------------------
MODIFIED_STARTUP=$(eval echo "$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')")
log_message "서버 시작: ${MODIFIED_STARTUP}" "info"

exec ${MODIFIED_STARTUP}
