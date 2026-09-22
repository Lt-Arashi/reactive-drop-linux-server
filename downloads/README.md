# 本地下载目录

本目录用于放置需要在**本地(你自己的电脑)**下载、再上传到服务器的文件,避免服务器网络下载缓慢或超时。

## 需要放置的文件

### 1. `proton.tar.gz` (必需)

Proton GE 运行环境,用于在 Linux 上通过 wine 运行 Windows 版 Reactive Drop 专用服务器。

1. 在本地电脑下载 GE-Proton9-22 (约 400MB):
   - GitHub 直链:
     `https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-22/GE-Proton9-22.tar.gz`
   - 国内镜像加速(任选其一):
     - `https://ghproxy.net/https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-22/GE-Proton9-22.tar.gz`
     - `https://mirror.ghproxy.com/https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-22/GE-Proton9-22.tar.gz`
2. 把下载到的文件**重命名为 `proton.tar.gz`**。
3. 上传到服务器的 `downloads/` 目录,最终路径为 `downloads/proton.tar.gz`。

### 2. 基础镜像 `debian-bookworm-slim.tar` (强烈推荐)

构建镜像时需要从 Docker Hub 拉取 `debian:bookworm-slim` 基础镜像,国内服务器经常**超时**。
所以建议也在本地把它准备好、上传到服务器:

1. 在本地电脑(能正常访问 Docker Hub 的机器)执行:
   ```bash
   docker pull debian:bookworm-slim
   docker save debian:bookworm-slim -o debian-bookworm-slim.tar
   ```
2. 把 `debian-bookworm-slim.tar` 上传到服务器 `downloads/` 目录(注意: **不要** gzip 压缩,`docker load` 需要未压缩的 tar)。
3. `setup.sh install` 会自动 `docker load` 该镜像,构建时就不会再访问 Docker Hub。

> 任何放到 `downloads/` 下、以 `.tar` 结尾的镜像文件都会被自动 `docker load`。

### 备选:registry 镜像加速(daemon.json)

仓库根目录已自带 `daemon.json`,内含 `registry-mirrors` 镜像加速列表,`setup.sh install`
会自动把它复制到 `/etc/docker/daemon.json` 并重启 Docker。如果某个镜像源失效,直接编辑仓库里的
`daemon.json` 再重新 `./setup.sh install` 即可。

## 更换版本

- Proton:替换 `downloads/proton.tar.gz` 为对应版本 tarball,然后 `./setup.sh rebuild`。
- 基础镜像:重新 `docker pull && docker save` 上传覆盖即可。
