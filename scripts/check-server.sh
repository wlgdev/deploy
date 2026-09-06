#!/usr/bin/env bash
# Сверка сервера под wlgdev/deploy v1. Только проверки, ничего не меняет.
# Запуск со своей машины: ssh root@HOST 'bash -s' < scripts/check-server.sh
# Вариант для MobaXterm (зайти своим юзером, затем sudo -i, вставить блок):
#   id deploy
#   id -nG deploy | grep -qw docker && echo GROUP_OK
#   stat -c %U /data/apps
#   [ -s /home/deploy/.ssh/authorized_keys ] && echo KEY_OK
#   sudo -u deploy docker ps | head -3
#   sudo -u deploy docker compose version
#   sudo -u deploy grep -q ghcr.io /home/deploy/.docker/config.json && echo GHCR_OK
set -eu
fail=0
need() { if eval "$2" >/dev/null 2>&1; then echo "OK:   $1"; else echo "MISS: $1"; fail=1; fi }

need "user deploy exists"            "id deploy"
need "deploy in docker group"        "id -nG deploy | grep -qw docker"
need "/data/apps owned by deploy"     "[ \"\$(stat -c %U /data/apps)\" = deploy ]"
need "deploy authorized_keys present" "[ -s /home/deploy/.ssh/authorized_keys ]"
need "docker works for deploy"       "sudo -u deploy docker ps"
need "compose plugin for deploy"     "sudo -u deploy docker compose version"
need "ghcr.io auth for deploy"       "grep -q ghcr.io /home/deploy/.docker/config.json"

if [ "$fail" -eq 0 ]; then echo ALL_OK; else echo "--- fix MISS lines, re-run ---"; exit 1; fi
