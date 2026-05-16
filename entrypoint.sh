#!/bin/bash

gamefolder="/usr/lib/games/reactivedrop"
steamcmd="nice -n 19 ionice -c3 steamcmd"

function title() {
  echo ""
  echo $* | boxes -d stone
}

# 在首次安装完服务端并启动后,在不关闭docker的情况下可以注释掉检查steamcmd更新和检查游戏更新的部分,这可以一定程度上加速服务端的崩溃重启

title "检查SteamCMD更新"
$steamcmd +quit

title "正在检查游戏更新,这可能需要一些时间"
$steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir reactivedrop +login anonymous +app_update 563560 validate +app_update 1007 validate +quit
mkdir -p /root/.steamcmd

# .ain and .bsp files need to be in sync, someone decided to use timestamps for that, instead of hashes..
# reset dates on all files to the same as srcds.exe
title "修复 timestamps.."
touch -r "${gamefolder}/srcds.exe" -c \
  $(find "${gamefolder}/reactivedrop/maps" -type f -name '*.bsp' -or -name '*.ain')

cd $gamefolder || exit 1

title "正在设置游戏……"
echo "creating links.."

# steam proton is searching for ~/.steam/sdk32 for some steam libs
# these libs are installed in /usr/lib/games by the steamcmd debian package
mkdir -p /root/.steam
ln -sf /usr/lib/games/linux32 /root/.steam/sdk32

# symlink steam.dll as well, the game requires (but not ships it)
ln -sf /usr/lib/games/steam.dll "${gamefolder}/steam.dll"
ln -sf /usr/lib/games/steam.dll "${gamefolder}/reactivedrop/steam.dll"

# the game is somehow searching for steam_appid.txt outside its folder
# /opt is a folder is searches, so we just put it there to fix the workshop
# and steam connectivity
ln -sf "${gamefolder}/steam_appid.txt" /opt/steam_appid.txt

echo "writing settings.."

# copy defaults settings to the game folder
# cp /usr/local/settings.cfg "${gamefolder}/reactivedrop/cfg/autoexec.cfg"

# touch an empty workshop.cfg, since some users misinterprete the missing file message
truncate -s 0 "${gamefolder}/reactivedrop/cfg/workshop.cfg"
for a in $(set | grep workshop_item | cut -d '_' -f 3 | cut -d '=' -f 1); do
  echo "rd_enable_workshop_item ${a}" >>"${gamefolder}/reactivedrop/cfg/workshop.cfg"
done

echo "writing workshop.cfg.."
cat "${gamefolder}/reactivedrop/cfg/workshop.cfg"

# and store user setting too
set | grep '^rd_' | cut -d '_' -f 2- | tr '=' ' ' | tr -d "'" >"${gamefolder}/reactivedrop/cfg/user.cfg"

# 这里是启动项,根据需求更改
echo "starting game.."
truncate -s0 reactivedrop/console.log
screen -L -S game -dm wine srcds_console.exe -console -condebug -conclearlog -game reactivedrop \
  -tickrate 100 \
  -ip 0.0.0.0 \
  -port "${port:-27005}" \
  -maxplayers "${maxplayers}" \
  -noassert -nomessagebox \
  +map lobby

title "服务端运行于端口 ${port:-27005}"
tail -n 100 -F reactivedrop/console.log &

while true; do
  sleep 5
  pid=$(pgrep -f srcds_console)
  if [[ "$pid" == "" ]]; then
    echo "game exited."
    exit 10
  fi
done
