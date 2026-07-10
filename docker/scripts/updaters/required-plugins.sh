#!/bin/bash
# CS:GO 필수 플러그인을 카탈로그대로 설치한다 (없을 때만, sha256 검증)

# 버전을 고정했으므로 "업데이트"는 없다. marker 파일이 있으면 건너뛴다.
# 사람이 카탈로그의 url/sha256 을 올릴 때만 새로 받는다 (marker 를 지우고 재기동).

# $1=카탈로그 json  $2=대상 csgo 디렉터리  $3=임시 디렉터리
install_required_plugins() {
    local catalog="$1" dst="$2" tmp="$3"
    [ -f "$catalog" ] || { echo "카탈로그 없음: $catalog" >&2; return 1; }
    mkdir -p "$tmp"

    local count i
    count=$(jq '.plugins | length' "$catalog")

    for ((i = 0; i < count; i++)); do
        local name url type sha marker
        name=$(jq -r ".plugins[$i].name" "$catalog")
        url=$(jq -r ".plugins[$i].url" "$catalog")
        type=$(jq -r ".plugins[$i].type" "$catalog")
        sha=$(jq -r ".plugins[$i].sha256" "$catalog")
        marker=$(jq -r ".plugins[$i].marker" "$catalog")

        if [ -f "$dst/$marker" ]; then
            echo "  skip    $name (이미 있음)"
            continue
        fi

        local file="$tmp/$(basename "$url")"
        if ! curl -fsSL "$url" -o "$file"; then
            echo "  FAIL    $name (다운로드 실패)" >&2
            return 1
        fi

        local got
        got=$(sha256sum "$file" | cut -d' ' -f1)
        if [ "$got" != "$sha" ]; then
            echo "  FAIL    $name (sha256 불일치)" >&2
            echo "          기대 $sha" >&2
            echo "          실제 $got" >&2
            rm -f "$file"
            return 1
        fi

        case "$type" in
            smx)
                mkdir -p "$dst/$(dirname "$marker")"
                cp -f "$file" "$dst/$marker"
                ;;
            zip)
                # 배포 zip 은 addons/ 트리를 통째로 담고 있다. gamedata 도 같이 온다.
                unzip -qo "$file" -d "$tmp/${name}_x" || return 1
                cp -rn "$tmp/${name}_x/addons/." "$dst/addons/" 2>/dev/null || true
                ;;
            *)
                echo "  FAIL    $name (알 수 없는 type: $type)" >&2
                return 1
                ;;
        esac

        echo "  install $name"
    done
    return 0
}
