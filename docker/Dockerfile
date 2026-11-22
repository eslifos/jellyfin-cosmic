# Uses the files already compiled by the release workflow (payload/linux-<arch> and payload/web).
FROM mcr.microsoft.com/dotnet/runtime-deps:10.0

ARG TARGETARCH

ENV JELLYFIN_DATA_DIR=/config \
    JELLYFIN_CACHE_DIR=/cache \
    JELLYFIN_LOG_DIR=/config/log \
    JELLYFIN_WEB_DIR=/opt/jellyfin-cosmic/web \
    PATH=/opt/jellyfin-cosmic/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    MALLOC_TRIM_THRESHOLD_=131072 \
    MALLOC_ARENA_MAX=2 \
    DOTNET_GCConserveMemory=5 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        ffmpeg \
        fonts-dejavu-core \
        libfontconfig1 \
        libfreetype6 \
        mkvtoolnix \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -l jellyfin -d /config -s /usr/sbin/nologin -G video ubuntu \
    && groupmod -n jellyfin ubuntu \
    && mkdir -p /config /cache /media

COPY payload/linux-${TARGETARCH}/ /opt/jellyfin-cosmic/
COPY payload/web/ /opt/jellyfin-cosmic/web/

RUN chmod 755 /opt/jellyfin-cosmic/server/jellyfin \
    && chown -R jellyfin:jellyfin /config /cache /media /opt/jellyfin-cosmic/tools

USER jellyfin

VOLUME ["/config", "/cache"]
EXPOSE 8096 8920

HEALTHCHECK --interval=30s --timeout=10s --start-period=2m --retries=3 \
    CMD curl -fsS http://localhost:8096/health || exit 1

ENTRYPOINT ["/opt/jellyfin-cosmic/server/jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache", \
    "--logdir", "/config/log", \
    "--webdir", "/opt/jellyfin-cosmic/web", \
    "--ffmpeg", "/usr/bin/ffmpeg"]
