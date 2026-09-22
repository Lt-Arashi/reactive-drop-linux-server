# 更适合中国宝宝体质的 Reactive Drop Linux Server

基于 [Mithrand](https://github.com/mithrand0) 原版改造,针对国内网络环境做了以下优化:

- 一键脚本自动安装 Docker、配置镜像加速,无需预先准备环境
- Proton GE 等大文件改为本地下载后上传,避免服务器下载缓慢
- 使用游戏原生 `workshop.cfg`,不再用 `workshop_item_*` 环境变量
- 不再内置/覆盖任何游戏配置,全部由你上传自己的 cfg
- 重启不再每次校验更新,仅在首次安装和 `./setup.sh update` 时更新

## 准备

- 一台 Linux 服务器(Ubuntu 24.04 测试通过)
- 本地下载 Proton GE 并上传(见 `downloads/README.md`)
- Docker 镜像加速已内置在根目录的 `daemon.json`(registry-mirrors),可按需修改

## 使用步骤

1. 把本仓库上传到服务器(或用 `git clone`)。
2. 本地下载 Proton GE 并上传,得到 `downloads/proton.tar.gz`(见 `downloads/README.md`)。
3. 在仓库目录执行一键安装(会安装 Docker、构建镜像、启动):
   ```bash
   cd reactive-drop-linux-server
   sudo ./setup.sh install
   ```
4. 上传你自己的游戏配置到 `reactivedrop/reactivedrop/cfg/`:
   - `server.cfg` / `autoexec.cfg` —— 服务器设置(hostname、rcon_password、rd_* 等)
   - `workshop.cfg` —— 创意工坊,每行 `rd_enable_workshop_item <id>`

   改完后执行 `./setup.sh restart` 生效。

## 多实例 / CPU 限制

一台机器跑多个实例时,建议给每个实例固定核心,避免互相争抢。在 `.env` 里设置 `CPUSET`(核心亲和):

```bash
# 实例 A: 只用 0 号核心
CPUSET=0
# 实例 B: 只用 1 号核心
CPUSET=1
```

留空则不限。改完 `./setup.sh up` 生效。查看核心:`nproc` / `lscpu`。

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `./setup.sh install` | 一键安装(装 Docker + 构建 + 启动) |
| `./setup.sh update` | 触发游戏更新(steamcmd 校验)并重启 |
| `./setup.sh up` | 启动/重建容器(**改 `.env` 后用这个生效**) |
| `./setup.sh restart` | 重启容器(不更新,速度快;**改 cfg 文件后用这个生效**) |
| `./setup.sh rebuild` | 重新构建镜像(改 Dockerfile / entrypoint.sh 后) |
| `./setup.sh console` | 进入游戏控制台(退出: Ctrl+A 再按 D) |
| `./setup.sh logs` | 持续查看日志 |
| `./setup.sh status` | 查看容器状态 |

## 声明

- 我不是专业人士,只能确保它在 Ubuntu 24.04 上运行良好,相关命令均来自网络。
- 代码原作者 [**Mithrand**](https://github.com/mithrand0),我只是针对网络环境做了修改。
- 至于为什么不是原仓库的 fork —— 我左脑肘击右脑不小心解除了 fork 关系。

## 希望能帮到你
