# CS2.KR CS:GO Egg

CS:GO(appid 740, Source 1) 전용 Pterodactyl egg 와 Docker 이미지입니다.
CS2 용인 [CS2KR/cs2-egg](https://github.com/CS2KR/cs2-egg) 의 자매 저장소이고,
그쪽을 통해 [K4ryuu/CS2-Egg](https://github.com/K4ryuu/CS2-Egg) (GPL-3.0) 를 뿌리로 합니다.

## 무엇을 하나

컨테이너가 뜰 때마다 이 순서로 돕니다.

1. `csgo-vpk-daemon` 이 게임 파일을 넣을 때까지 대기 (`egg/.daemon-managed` 마커)
2. `egg/configs/` 에 기본 설정 시딩 (없을 때만)
3. `cleanup.json` 규칙대로 오래된 로그·덤프 삭제
4. MetaMod:Source · SourceMod 설치 (버전 고정)
5. CS:GO 서비스 종료 이후 필수인 플러그인 3종 설치 (없을 때만)
6. `srcds_run` 실행

## ⚠ 덮어쓰지 않는 것

이 egg 의 가장 중요한 성질입니다. **서버에 쌓인 작업물을 지우지 않습니다.**

SourceMod 타르볼은 `addons/sourcemod/` 를 통째로 담고 있어서, 그냥 풀면 한국어 번역과
재컴파일한 스톡 플러그인이 매 부팅 스톡으로 되돌아갑니다. 그래서 경로를 나눕니다.

| 경로 | 정책 |
|------|------|
| `sourcemod/bin`, `extensions`, `gamedata`, `scripting/include` | 매번 갱신 |
| `metamod/bin` | 매번 갱신 |
| `sourcemod/plugins`, `translations`, `configs`, `scripting` | **없을 때만** |
| `sourcemod/data`, `logs` | 손대지 않음 |

`plugins/` 가 "없을 때만" 인 이유는, 스톡 `.smx` 조차 CS2.KR 접두사로 재컴파일돼 있기 때문입니다.

## 필수 플러그인

전부 원저작자 저장소에서 태그·커밋으로 고정해 받습니다. 재배포하지 않습니다.

| 플러그인 | 왜 |
|---|---|
| [NoLobbyReservation](https://github.com/vanz666/NoLobbyReservation) | 2024-02 `csgo_legacy` 이후 로비 예약 문제 |
| [MapCrashFixer](https://github.com/ismail0234/Benson-Map-Crash-Fixer) | 맵 전환 중 클라이언트 크래시 |
| [FixHintColorMessages](https://github.com/Franc1sco/FixHintColorMessages) | speedpanel/hint 메시지 색 깨짐 |

목록과 sha256 은 `docker/defaults/required-plugins.json` 에 있습니다.
`sha256` 이 어긋나면 설치하지 않고 실패합니다.

## MetaMod / SourceMod 버전

AlliedModders 에는 `stable` 이라는 별칭 URL 이 **없습니다.** 브랜치별 포인터 파일만 있습니다.

```
https://sm.alliedmods.net/smdrop/<branch>/sourcemod-latest-linux
https://mms.alliedmods.net/mmsdrop/<branch>/mmsource-latest-linux
```

그래서 egg 변수로 브랜치와 버전을 받습니다. 운영에서는 `SM_VERSION` / `MM_VERSION` 을
채워 **고정**하십시오. 비우면 브랜치 최신을 따라갑니다.

현재 stable 은 둘 다 `1.12` 입니다. MetaMod 에 `1.13` 브랜치는 없습니다.

## 중앙 게임 파일 (`misc/update-csgo-centralized.sh`)

노드 하나에 CS:GO 설치본을 한 벌만 두고, 각 서버 볼륨에는 vpk 를 심볼릭 링크로 겁니다.
`/srv/csgo-shared` 가 컨테이너 안 `/tmp/csgo-shared` 로 읽기 전용 bind mount 됩니다.

`BASE_FILES_SYNC` 로 **vpk 가 아닌 파일(엔진 바이너리 등)** 을 언제 밀어 넣을지 정합니다.

- `auto` (기본) — 첫 부팅, 또는 공유 설치본의 buildid 가 바뀌었을 때만
- `always` — 매번. `csgo/` 아래 파일이 부팅마다 스톡으로 되돌아갑니다
- `never` — 절대 밀지 않음

예전 동작이 `always` 였고, 그래서 `csgo/` 에 둔 파일이 조용히 사라졌습니다.

호스트에는 이렇게 겁니다.

```bash
sudo ln -sfn /opt/cs2kr/csgo-egg/misc/update-csgo-centralized.sh \
             /usr/local/bin/update-csgo-centralized.sh
sudo systemctl restart csgo-vpk-daemon.service   # 게임 컨테이너는 재시작되지 않습니다
```

새 이미지를 쓰는 서버를 만들 때는 스크립트의 `SERVER_IMAGE` 에
`ghcr.io/cs2kr/csgo-egg` 를 **반드시 추가**하십시오. 빠뜨리면 데몬이 vpk 를 밀지 않습니다.

## 라이선스

GPL-3.0. 원저작자 K4ryuu @ KitsuneLab. `LICENSE.md` 를 보십시오.
