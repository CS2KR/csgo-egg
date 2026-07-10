# Dockerfile with SteamRT3 — CS:GO(32비트 srcds) 용
FROM        registry.gitlab.steamos.cloud/steamrt/sniper/platform:latest-container-runtime-depot
LABEL       author="CS2.KR" \
            maintainer="contact@cs2.kr" \
            org.opencontainers.image.description="CS2.KR CS:GO egg image. MetaMod/SourceMod and post-EOL required plugins are installed on boot." \
            org.opencontainers.image.source="https://github.com/CS2KR/csgo-egg" \
            org.opencontainers.image.licenses="GPL-3.0" \
            org.opencontainers.image.base.name="https://github.com/K4ryuu/CS2-Egg"

# sniper 베이스에는 i386 런타임(/lib/ld-linux.so.2)이 이미 있다.
# srcds_linux 의 누락 라이브러리 0을 실측으로 확인했다 (2026-07-10).

RUN         mkdir -p /etc/sudoers.d && \
            echo "%sudo ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/flatdeb && \
            chmod 0440 /etc/sudoers.d/flatdeb

ENV         DEBIAN_FRONTEND=noninteractive
RUN         apt update && \
            apt install -y iproute2 jq unzip curl && \
            apt-get clean

RUN         mkdir -p /scripts /utils /defaults
COPY        ./scripts /scripts/
COPY        ./utils /utils/
COPY        ./defaults /defaults/
COPY        ./entrypoint.sh /entrypoint.sh

RUN         chmod 555 /scripts/*.sh && \
            chmod 555 /scripts/updaters/*.sh && \
            chmod 555 /utils/*.sh && \
            chmod 444 /defaults/*.json && \
            chmod 555 /entrypoint.sh

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

CMD         [ "/bin/bash", "/entrypoint.sh" ]
