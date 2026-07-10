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

## 중앙 게임 파일 공유 (`misc/`)

CS:GO 설치본은 33GB 입니다. 서버마다 한 벌씩 두면 노드 디스크가 남아나지 않습니다.
그래서 노드에 **한 벌만** 두고 각 서버 볼륨에는 vpk 를 심볼릭 링크로 겁니다.

### 어떻게 동작하나

```
호스트                                컨테이너
/srv/csgo-shared/                     /tmp/csgo-shared/        (읽기 전용 bind mount)
  csgo/pak01_000.vpk  ◄───────────────  ▲
                                        │
/var/lib/pterodactyl/volumes/<uuid>/    │
  csgo/pak01_000.vpk ──심볼릭 링크──────┘
  csgo/addons/            ← 서버 고유. 절대 건드리지 않음
  bin/, platform/, srcds_linux   ← 엔진 파일. 실체로 존재해야 함
```

`csgo-vpk-daemon` 이 `docker events` 를 감시하다가 컨테이너가 뜨면 이 일을 합니다.

1. `nsenter` 로 `/srv/csgo-shared` 를 컨테이너의 마운트 네임스페이스에 꽂습니다
   → `docker inspect` 의 `Mounts` 에는 **안 보입니다.** `/proc/<PID>/mounts` 에만 있습니다
2. 볼륨의 vpk 심볼릭 링크를 확인·갱신합니다 (멱등. 이미 맞으면 건너뜁니다)
3. 필요할 때만 vpk 가 아닌 파일을 rsync 합니다 (아래)
4. `egg/.daemon-managed` 마커를 남깁니다 → egg 의 entrypoint 가 이걸 기다립니다

**이미 돌고 있는 컨테이너는 건드리지 않습니다.** 데몬을 재시작해도 게임 서버는 그대로입니다.

### ⚠ `BASE_FILES_SYNC` — 예전 동작이 파일을 지우고 있었습니다

이름은 vpk sync 인데, 옛 스크립트는 `--exclude '*.vpk'` 로 **정작 vpk 만 빼고**
`csgo/` 나머지 트리를 컨테이너가 뜰 때마다 볼륨 위에 덮어썼습니다.
그래서 `csgo/` 에 둔 파일이 조용히 스톡으로 되돌아갔습니다.

이제 `BASE_FILES_SYNC` 가 그 rsync 를 통제합니다.

| 값 | 언제 밀어 넣나 |
|---|---|
| `auto` (기본) | 첫 부팅(`srcds_linux` 없음), 또는 공유 설치본의 **buildid 가 바뀌었을 때만** |
| `always` | 매번. 옛 동작입니다. `csgo/` 아래가 부팅마다 되돌아갑니다 |
| `never` | 절대 밀지 않음. 볼륨에 엔진 파일이 이미 있어야 합니다 |

`auto` 는 볼륨마다 `egg/.base-files-buildid` 에 buildid 를 적어 판단합니다.
스탬프가 없고 파일은 있는 볼륨(=기존 서버)은 **스탬프만 찍고 건너뜁니다.**
진짜 게임 업데이트는 여전히 전파되고, 매 부팅 덮어쓰기는 사라집니다.

rsync 는 어차피 `csgo/addons/`, `csgo/cfg/`, `gameinfo.txt`, `mapcycle.txt`, `maplist.txt` 를 제외합니다.

### 설치

wings 노드(게임 서버가 실제로 도는 호스트)에서 실행합니다. 패널 호스트가 아닙니다.

**한 줄로 설치**

```bash
curl -fsSL https://raw.githubusercontent.com/CS2KR/csgo-egg/main/misc/install-csgo-update.sh | sudo bash
```

같은 명령으로 **갱신**도 됩니다. 최신 스크립트를 받아 다르면 교체하고, 같으면 아무것도 하지 않습니다.
교체할 때는 기존 스크립트를 `.bak-<timestamp>` 로 남깁니다 — CONFIG 블록을 고쳤다면 옮겨 적으십시오.

**저장소를 두고 쓰려면**

```bash
sudo git clone https://github.com/CS2KR/csgo-egg /opt/cs2kr/csgo-egg
sudo bash /opt/cs2kr/csgo-egg/misc/install-csgo-update.sh
```

이 경우 `git pull` 로 갱신하고 설치 스크립트를 다시 돌리면 됩니다.

`install-csgo-update.sh` 가 하는 일입니다. **여러 번 돌려도 안전합니다.**

1. 의존성 확인 — `docker` `rsync` `curl` `python3` `nsenter`
2. `misc/update-csgo-centralized.sh` 를 `/opt/cs2kr/csgo-egg/misc/` 에 배치
3. `/usr/local/bin/update-csgo-centralized.sh` 를 거기로 **심볼릭 링크**
   (기존 실파일이 있으면 `.bak-<timestamp>` 로 옮깁니다. 덮어쓰지 않습니다)
4. `csgo-vpk-daemon.service` 등록 후 기동

게임 파일 자체는 받지 않습니다. `/srv/csgo-shared` 가 없으면 이렇게 먼저 받으십시오.

```bash
steamcmd +force_install_dir /srv/csgo-shared +login anonymous +app_update 740 +quit
```

CS:GO 는 서비스가 종료돼 업데이트가 없으므로 **cron 은 걸지 않습니다.**

### 설정

`misc/update-csgo-centralized.sh` 상단의 CONFIG 블록을 직접 고칩니다.

| 변수 | 기본값 | 뜻 |
|---|---|---|
| `CSGO_DIR` | `/srv/csgo-shared` | 공유 설치본 |
| `STEAMCMD_DIR` | `/root/steamcmd` | SteamCMD 위치 |
| `SERVER_IMAGE` | (아래) | **감시할 이미지 목록.** 여기 없는 이미지는 vpk 를 못 받습니다 |
| `VPK_PUSH_METHOD` | `symlink` | `symlink` / `hardlink` / `copy` / `off` |
| `BASE_FILES_SYNC` | `auto` | 위 표 참조 |
| `AUTO_RESTART_SERVERS` | `true` | 게임 업데이트 후 서버 자동 재시작 |

`SERVER_IMAGE` 에는 `ghcr.io/cs2kr/csgo-egg` 가 **이미 들어 있습니다.** 새 이미지를 만들어
쓴다면 반드시 추가하십시오. 빠뜨리면 데몬이 그 컨테이너를 무시해 **게임 파일 없이 뜹니다.**

### 사용법

```bash
update-csgo-centralized.sh              # 업데이트 확인 후 각 볼륨에 push
update-csgo-centralized.sh --simulate   # SteamCMD 를 건너뛰고 push 경로만 시험
update-csgo-centralized.sh --validate   # 이번 실행만 steamcmd validate
update-csgo-centralized.sh --daemon     # 이벤트 감시 (systemd 가 이걸 씁니다)
```

### 확인

```bash
systemctl status csgo-vpk-daemon
journalctl -u csgo-vpk-daemon -f

# 볼륨의 vpk 가 심볼릭 링크인가
ls -l /var/lib/pterodactyl/volumes/<uuid>/csgo/pak01_000.vpk

# 컨테이너 안에서 원본이 보이는가 (docker inspect 로는 안 보입니다)
grep csgo-shared /proc/$(docker inspect -f '{{.State.Pid}}' <container>)/mounts

# 이 볼륨이 어느 buildid 로 동기화됐나
cat /var/lib/pterodactyl/volumes/<uuid>/egg/.base-files-buildid
```

### 롤백

```bash
sudo rm /usr/local/bin/update-csgo-centralized.sh
sudo mv /usr/local/bin/update-csgo-centralized.sh.bak-<timestamp> \
        /usr/local/bin/update-csgo-centralized.sh
sudo systemctl restart csgo-vpk-daemon
```

데몬 재시작은 게임 서버를 재시작하지 않습니다.

## 라이선스

GPL-3.0. 원저작자 K4ryuu @ KitsuneLab. `LICENSE.md` 를 보십시오.
