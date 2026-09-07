          install -m 700 -d ~/.ssh
          printf '%s\n' "$SSH_KEY" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          : "${SSH_USER:=deploy}"
          : "${SSH_PORT:=22}"
          ssh-keyscan -p "$SSH_PORT" -H "$SSH_HOST" >> ~/.ssh/known_hosts
          SSH="ssh -i ~/.ssh/deploy_key -p $SSH_PORT -o StrictHostKeyChecking=yes"
          REMOTE="$SSH_USER@$SSH_HOST"
          $SSH "$REMOTE" "mkdir -p /data/apps/$APP"
          scp -P "$SSH_PORT" -i ~/.ssh/deploy_key "app/$COMPOSE_PATH" "$REMOTE:/data/apps/$APP/docker-compose.yml.new"
          if [ -f "docker-compose.override.yml" ]; then
            scp -P "$SSH_PORT" -i ~/.ssh/deploy_key "docker-compose.override.yml" "$REMOTE:/data/apps/$APP/docker-compose.override.yml.new"
          fi
          if [ -n "$ENV_INPUT" ]; then
            printf '%s' "$ENV_INPUT" | $SSH "$REMOTE" "cat > /data/apps/$APP/.env.tmp && chmod 600 /data/apps/$APP/.env.tmp"
          fi
          echo "📄 compose uploaded → /data/apps/$APP/docker-compose.yml"
          $SSH "$REMOTE" "cd /data/apps/$APP && rm -f .env && mv docker-compose.yml.new docker-compose.yml && if [ -f docker-compose.override.yml.new ]; then mv docker-compose.override.yml.new docker-compose.override.yml; else rm -f docker-compose.override.yml; fi && if [ -f .env.tmp ]; then while IFS='=' read -r k v || [ -n \"\$k\" ]; do case \"\$k\" in ''|\#*) ;; *) export \"\$k=\$v\";; esac; done < .env.tmp; rm -f .env.tmp; fi && docker compose pull && docker compose up -d --remove-orphans && if [ -f docker-compose.override.yml ]; then (docker network inspect \"proxy-$APP-network\" >/dev/null 2>&1 || docker network create \"proxy-$APP-network\") && if docker ps --format '{{.Names}}' | grep -qx coolify-proxy; then docker inspect -f '{{json .NetworkSettings.Networks}}' coolify-proxy | grep -q \"\\\"proxy-$APP-network\\\"\" || docker network connect \"proxy-$APP-network\" coolify-proxy; fi; else if docker network inspect \"proxy-$APP-network\" >/dev/null 2>&1; then docker network disconnect \"proxy-$APP-network\" coolify-proxy 2>/dev/null || true; docker network rm \"proxy-$APP-network\"; fi; fi && docker image prune -f && docker image prune -a -f --filter \"until=168h\" && docker compose ps"
          echo -e "\033[1;32m✅ $APP is up\033[0m"
