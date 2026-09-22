FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND="noninteractive"

# 使用清华镜像源(含 steamcmd 所需的 non-free)
# 注意用 http 而非 https: 基础镜像未装 ca-certificates, 用 https 会因缺少系统证书导致 apt update 失败
# (先有鸡还是先有蛋的问题)。apt 的包本身靠 GPG 签名校验完整性, 走 http 是安全的。
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; s|main|main contrib non-free non-free-firmware|g' /etc/apt/sources.list.d/debian.sources \
 && dpkg --add-architecture i386

# 预置 steam 授权(必须在安装 steamcmd 之前), 先装 debconf 以支持预置
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt/archives,sharing=locked \
    apt -qq update \
 && apt -y install --no-install-recommends ca-certificates debconf \
 && echo steam steam/question select "I AGREE" | debconf-set-selections \
 && echo steam steam/license note '' | debconf-set-selections

# 系统依赖一次性装齐
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt/archives,sharing=locked \
    apt -qq update \
 && apt -y install --no-install-recommends \
      steamcmd \
      libc6-i386 lib32gcc-s1 libnss-resolve:i386 \
      libfreetype6:i386 libfontconfig1:i386 \
      libfreetype6 libxft2 \
      locales less procps vim-tiny boxes screen \
      psmisc strace htop

# Proton(本地下载: downloads/proton.tar.gz, 用 bind mount 避免写入镜像层以减小体积)
RUN --mount=type=bind,source=downloads/proton.tar.gz,target=/tmp/proton.tar.gz \
    tar xzf /tmp/proton.tar.gz -C /opt

# 展开 proton 用到的路径
ENV LD_LIBRARY_PATH="/usr/lib/games/steam:/usr/lib/games/linux32"
ENV PATH="/usr/lib/games/steam:/usr/lib/games/linux32:/opt/bin:$PATH"

# 链接 wine 到 PATH
RUN mkdir -p /opt/bin && find /opt -type f -name 'wine' -exec ln -sf {} /opt/bin/ \;

# locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
 && sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen \
 && locale-gen
ENV LANG=zh_CN.UTF-8
ENV LC_ALL=zh_CN.UTF-8

# 复制脚本与 steam.dll(游戏需要但不自带)
COPY entrypoint.sh /
COPY steam.dll /usr/lib/games/

ENV WINEARCH=win64
ENV WINEDEBUG=-all

VOLUME /usr/lib/games/reactivedrop
WORKDIR /usr/lib/games/reactivedrop

ENTRYPOINT [ "/entrypoint.sh" ]
