#!/bin/bash
# MetaMod:Source 와 SourceMod 를 AlliedModders 배포처에서 설치한다 (CS:GO, 버전 고정)

# `stable` 이라는 별칭 URL 은 없다. 브랜치별 포인터 파일만 있다.
#   https://sm.alliedmods.net/smdrop/<branch>/sourcemod-latest-linux
#   https://mms.alliedmods.net/mmsdrop/<branch>/mmsource-latest-linux
# SM_VERSION / MM_VERSION 이 있으면 그것을 쓰고, 없을 때만 포인터를 읽는다.

SM_DROP="https://sm.alliedmods.net/smdrop"
MM_DROP="https://mms.alliedmods.net/mmsdrop"

# 덮어써도 되는 경로. 엔진 산출물뿐이다.
# plugins/ 는 없다 — 스톡 .smx 도 CS2.KR 접두사로 재컴파일돼 있다 (sm-base-ko).
SM_OVERWRITE=(bin extensions gamedata scripting/include)

# 없을 때만 설치하는 경로. 한국어 번역과 DB 설정이 여기 산다.
SM_SEED=(configs translations plugins scripting)

# 배포 파일명을 정한다. $1=product(sourcemod|mmsource) $2=branch $3=pinned version
resolve_tarball() {
    local product="$1" branch="$2" pinned="$3"
    if [ -n "$pinned" ]; then
        echo "${product}-${pinned}-linux.tar.gz"
        return 0
    fi
    local base pointer
    case "$product" in
        sourcemod) base="$SM_DROP" ; pointer="sourcemod-latest-linux" ;;
        mmsource)  base="$MM_DROP" ; pointer="mmsource-latest-linux" ;;
        *) return 1 ;;
    esac
    # 포인터 파일에는 개행이 없다. 그대로 쓰면 뒷 문자열과 붙는다.
    curl -fsSL "${base}/${branch}/${pointer}" | tr -d '\r\n' || return 1
}

# $1=product $2=branch $3=tarball $4=목적지(addons 의 부모)
fetch_and_extract() {
    local product="$1" branch="$2" tarball="$3" tmp="$4"
    local base
    case "$product" in
        sourcemod) base="$SM_DROP" ;;
        mmsource)  base="$MM_DROP" ;;
    esac
    mkdir -p "$tmp"
    curl -fsSL "${base}/${branch}/${tarball}" -o "$tmp/${tarball}" || return 1
    tar xzf "$tmp/${tarball}" -C "$tmp" || return 1
}

# SourceMod 를 화이트리스트대로 깐다. $1=추출 디렉터리 $2=대상 csgo 디렉터리
install_sourcemod_tree() {
    local src="$1/addons/sourcemod" dst="$2/addons/sourcemod"
    [ -d "$src" ] || return 1
    mkdir -p "$dst"

    local p
    for p in "${SM_OVERWRITE[@]}"; do
        [ -e "$src/$p" ] || continue
        mkdir -p "$dst/$p"
        cp -rf "$src/$p/." "$dst/$p/"
    done

    for p in "${SM_SEED[@]}"; do
        [ -e "$src/$p" ] || continue
        mkdir -p "$dst/$p"
        cp -rn "$src/$p/." "$dst/$p/" 2>/dev/null || true
    done

    # SourceMod 를 MetaMod 에 물리는 vdf. 타르볼은 addons/metamod/sourcemod.vdf 로 준다
    # (addons/sourcemod.vdf 가 아니다 — 2026-07-10 실측)
    if [ -f "$1/addons/metamod/sourcemod.vdf" ]; then
        mkdir -p "$2/addons/metamod"
        cp -n "$1/addons/metamod/sourcemod.vdf" "$2/addons/metamod/" 2>/dev/null || true
    fi
    return 0
}

# MetaMod 는 바이너리만 갈고 나머지는 없을 때만.
# 타르볼 구조: addons/metamod.vdf, addons/metamod_x64.vdf, addons/metamod/{bin,metaplugins.ini}
# CS:GO srcds 는 32비트라 metamod_x64.vdf 는 쓰지 않는다.
install_metamod_tree() {
    local src="$1/addons/metamod" dst="$2/addons/metamod"
    [ -d "$src" ] || return 1

    mkdir -p "$dst/bin"
    cp -rf "$src/bin/." "$dst/bin/"

    [ -f "$src/metaplugins.ini" ] && cp -n "$src/metaplugins.ini" "$dst/" 2>/dev/null
    [ -f "$1/addons/metamod.vdf" ] && cp -n "$1/addons/metamod.vdf" "$2/addons/" 2>/dev/null
    return 0
}
