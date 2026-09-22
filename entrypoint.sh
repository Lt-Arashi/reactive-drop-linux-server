#!/bin/bash

gamefolder="/usr/lib/games/reactivedrop"
steamcmd="nice -n 19 ionice -c3 steamcmd"

function title() {
  echo ""
  echo "$*" | boxes -d stone
}

# ---- 更新策略: 仅首次安装(.installed 不存在)或显式触发(.update 存在)时, 才运行 steamcmd 校验更新 ----
mkdir -p /root/.steamcmd

if [[ ! -f "${gamefolder}/.installed" || -f "${gamefolder}/.update" ]]; then
  title "检查SteamCMD更新"
  $steamcmd +quit

  title "正在检查游戏更新,这可能需要一些时间"
  $steamcmd +@sSteamCmdForcePlatformType windows \
    +force_install_dir "${gamefolder}" \
    +login anonymous \
    +app_update 582400 validate \
    +app_update 1007 validate \
    +quit

  if [[ -f "${gamefolder}/srcds_console.exe" ]]; then
    touch "${gamefolder}/.installed"
    rm -f "${gamefolder}/.update"
  else
    echo "游戏安装/更新失败, 请检查网络后重试 (宿主机执行 ./setup.sh update)" >&2
    exit 1
  fi
else
  title "已安装, 跳过更新"
  echo "如需更新游戏, 请在宿主机执行: ./setup.sh update"
fi

# .ain and .bsp files need to be in sync, someone decided to use timestamps for that, instead of hashes..
# reset dates on all files to the same as srcds.exe
title "修复 timestamps.."
touch -r "${gamefolder}/srcds.exe" -c \
  $(find "${gamefolder}/reactivedrop/maps" -type f -name '*.bsp' -or -name '*.ain')

cd "$gamefolder" || exit 1

title "正在设置游戏……"
echo "creating links.."

# steam proton is searching for ~/.steam/sdk32 for some steam libs
mkdir -p /root/.steam
ln -sf /usr/lib/games/linux32 /root/.steam/sdk32

# symlink steam.dll as well, the game requires (but not ships it)
ln -sf /usr/lib/games/steam.dll "${gamefolder}/steam.dll"
ln -sf /usr/lib/games/steam.dll "${gamefolder}/reactivedrop/steam.dll"

# the game is somehow searching for steam_appid.txt outside its folder
ln -sf "${gamefolder}/steam_appid.txt" /opt/steam_appid.txt

# 确保 workshop.cfg 存在(缺失时游戏会打印警告), 但绝不覆盖用户上传的内容
if [[ ! -f "${gamefolder}/reactivedrop/cfg/workshop.cfg" ]]; then
  mkdir -p "${gamefolder}/reactivedrop/cfg"
  cat >"${gamefolder}/reactivedrop/cfg/workshop.cfg" <<'EOF'
// 在此填写需要启用的创意工坊项目, 每行一个, 例如:
// rd_enable_workshop_item 123456789
EOF
fi

echo "starting game.."
truncate -s0 reactivedrop/console.log
screen -S game -dm wine srcds_console.exe -console -condebug -game reactivedrop \
  -tickrate "${TICKRATE:-100}" \
  -ip 0.0.0.0 \
  -port "${PORT:-27050}" \
  -maxplayers "${MAXPLAYERS:-16}" \
  -noassert -nomessagebox \
  +map lobby

title "服务端运行于端口 ${PORT:-27050}"
tail -n 100 -F reactivedrop/console.log &

while true; do
  sleep 5
  pid=$(pgrep -f srcds_console)
  if [[ "$pid" == "" ]]; then
    echo "game exited."
    exit 10
  fi
done
