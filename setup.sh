#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Reactive Drop Linux Server 一键管理脚本
# 用法: ./setup.sh [install|update|rebuild|up|start|down|stop|restart|console|logs|status|help]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE=""

info() { echo -e "\033[36m[setup]\033[0m $*"; }
warn() { echo -e "\033[33m[setup]\033[0m $*"; }
err()  { echo -e "\033[31m[setup]\033[0m $*" >&2; }

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    err "请以 root 运行: sudo ./setup.sh $1"
    exit 1
  fi
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
  else
    COMPOSE=""
  fi
}

require_compose() {
  if [[ -z "$COMPOSE" ]]; then
    err "未检测到 docker compose, 请先运行: sudo ./setup.sh install"
    exit 1
  fi
}

docker_bin_present()  { command -v docker >/dev/null 2>&1; }
docker_daemon_up()    { docker info >/dev/null 2>&1; }

load_env() {
  if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
  fi
}

# ---- 安装 Docker ----
install_docker() {
  if docker_bin_present; then
    info "检测到 Docker 已安装"
  else
    info "未检测到 Docker, 开始安装..."
    if command -v curl >/dev/null 2>&1; then
      if curl -fsSL https://get.docker.com | bash -s -- --mirror Aliyun; then
        info "Docker 安装完成 (get.docker.com / Aliyun 镜像)"
      else
        warn "get.docker.com 安装失败, 回退到发行版 apt 安装"
        apt_install_docker_fallback
      fi
    else
      warn "未找到 curl, 改用发行版 apt 安装"
      apt_install_docker_fallback
    fi
  fi

  if ! docker_daemon_up; then
    info "启动 Docker 服务..."
    systemctl enable --now docker || service docker start || true
  fi

  detect_compose
  if [[ -z "$COMPOSE" ]]; then
    info "安装 docker compose 插件..."
    apt-get update -qq
    apt-get install -y docker-compose-plugin || apt-get install -y docker-compose-v2 || true
    detect_compose
  fi
}

apt_install_docker_fallback() {
  apt-get update -qq
  apt-get install -y docker.io docker-compose-v2
  systemctl enable --now docker || service docker start || true
}

# ---- 配置 Docker daemon(镜像加速等, 复制仓库里的 daemon.json 到 /etc/docker) ----
configure_docker_daemon() {
  if [[ ! -f daemon.json ]]; then
    warn "未找到 daemon.json, 跳过 Docker daemon 配置(构建时可能因网络超时)"
    return 0
  fi
  mkdir -p /etc/docker
  if [[ -f /etc/docker/daemon.json ]] && cmp -s daemon.json /etc/docker/daemon.json; then
    info "daemon.json 已是最新, 跳过"
    return 0
  fi
  info "复制 daemon.json 到 /etc/docker/daemon.json"
  if [[ -f /etc/docker/daemon.json ]]; then
    warn "已存在 /etc/docker/daemon.json, 备份为 daemon.json.bak 后覆盖"
    cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
  fi
  cp daemon.json /etc/docker/daemon.json
  systemctl restart docker || service docker restart || true
}

# ---- 校验本地下载文件 ----
check_downloads() {
  if [[ ! -f downloads/proton.tar.gz ]]; then
    err "缺少 downloads/proton.tar.gz (Proton GE 运行环境)"
    err "请在本机下载后上传到服务器 downloads/ 目录, 详见 downloads/README.md"
    err "  GitHub: https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-22/GE-Proton9-22.tar.gz"
    err "  镜像:   https://ghproxy.net/https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-22/GE-Proton9-22.tar.gz"
    err "下载后重命名为 proton.tar.gz 放到 downloads/, 再重新运行安装。"
    exit 1
  fi
  info "检测到 downloads/proton.tar.gz"
}

# ---- 加载本地镜像(避免构建时从 Docker Hub 拉取基础镜像) ----
load_local_images() {
  local img
  for img in downloads/*.tar; do
    [[ -e "$img" ]] || continue
    info "加载本地镜像: $img"
    docker load -i "$img"
  done
}

# ---- 子命令 ----
cmd_install() {
  require_root "install"
  [[ -f .env ]] || { cp .env.example .env; info "已从 .env.example 生成 .env (默认配置), 可随时修改"; }
  install_docker
  configure_docker_daemon
  check_downloads
  load_local_images
  load_env
  info "构建镜像..."
  $COMPOSE build
  info "启动服务..."
  $COMPOSE up -d
  info "完成! 查看日志: ./setup.sh logs"
  info "游戏配置(cfg / workshop)上传到 reactivedrop/reactivedrop/cfg/ 后 ./setup.sh restart 生效"
}

cmd_update() {
  require_root "update"
  require_compose
  mkdir -p reactivedrop
  info "标记游戏更新并重启容器..."
  touch reactivedrop/.update
  $COMPOSE restart
  info "已触发更新: 容器重启后会执行 steamcmd 校验并删除标记。"
}

cmd_rebuild() {
  require_root "rebuild"
  require_compose
  info "重建镜像..."
  $COMPOSE build
  mkdir -p reactivedrop
  # 重建镜像可能更新了 steam 运行时/steam.dll, 与卷里已下载的游戏文件版本不匹配会导致崩溃循环;
  # 打上 .update 标记, 让重建后的首次启动重新校验一次游戏文件(steamcmd)再启动。
  touch reactivedrop/.update
  $COMPOSE up -d
  info "重建完成, 首次启动会重新校验游戏文件。"
}

cmd_up()      { require_compose; $COMPOSE up -d; }
cmd_down()    { require_compose; $COMPOSE down; }
cmd_restart() { require_compose; $COMPOSE restart; }
cmd_logs()    { require_compose; $COMPOSE logs -f --tail=100; }
cmd_status()  { require_compose; $COMPOSE ps; }
cmd_console() { require_compose; $COMPOSE exec swarm screen -r game; }

cmd_help() {
  cat <<'EOF'
用法: ./setup.sh <命令>

  install   一键安装(装 Docker + 配置镜像 + 构建 + 启动) —— 首次使用
  update    触发游戏更新(steamcmd 校验)并重启
  rebuild   重新构建镜像(修改 Dockerfile / entrypoint.sh 后)
  up/start  启动容器
  down/stop 停止并删除容器
  restart   重启容器(不更新游戏, 速度快)
  console   进入游戏控制台(退出: Ctrl+A 再按 D)
  logs      持续查看日志
  status    查看容器状态
  help      显示本帮助
EOF
}

# ---- 入口 ----
detect_compose

case "${1:-install}" in
  install)      cmd_install ;;
  update)       cmd_update ;;
  rebuild)      cmd_rebuild ;;
  up|start)     cmd_up ;;
  down|stop)    cmd_down ;;
  restart)      cmd_restart ;;
  console)      cmd_console ;;
  logs)         cmd_logs ;;
  status)       cmd_status ;;
  help|-h|--help) cmd_help ;;
  *)
    err "未知命令: $1"
    cmd_help
    exit 1 ;;
esac
