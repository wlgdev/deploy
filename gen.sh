          set -eu
          python3 - << 'EOF'
          import os, sys

          target = os.environ.get("TARGET", "").strip()
          if not target:
              sys.exit(0)

          app = os.environ["APP"]
          is_dev = os.environ.get("IS_DEV") == "true"
          domain_suffix = "dev.wlg.tv" if is_dev else "wlg.tv"
          network_name = f"proxy-{app}-network"

          services = {}
          for line in target.splitlines():
              line = line.strip()
              if not line:
                  continue
              parts = line.split(":")
              if len(parts) != 3:
                  sys.exit(f"Invalid target entry: {line}")
              subdomain, service, port = parts
              subdomain = subdomain.removesuffix(".dev.wlg.tv").removesuffix(".wlg.tv")
              host = f"{subdomain}.{domain_suffix}"
              route = f"{app}-{service}"
              services[service] = {
                  "host": host,
                  "route": route,
                  "port": port,
              }

          lines = [
              "networks:",
              f"  {network_name}:",
              "    external: true",
              "services:",
          ]

          for service_name, cfg in services.items():
              route = cfg["route"]
              port = cfg["port"]
              host = cfg["host"]
              lines.extend([
                  f"  {service_name}:",
                  "    networks:",
                  "      - default",
                  f"      - {network_name}",
                  "    labels:",
                  "      - \"traefik.enable=true\"",
                  f"      - \"traefik.http.services.{route}.loadbalancer.server.port={port}\"",
                  f"      - \"traefik.http.routers.{route}.rule=Host(`{host}`)\"",
                  f"      - \"traefik.http.routers.{route}.tls=true\"",
                  f"      - \"traefik.http.routers.{route}.tls.certresolver=letsencrypt\"",
                  f"      - \"traefik.http.routers.{route}.entrypoints=websecure\"",
                  f"      - \"traefik.docker.network={network_name}\"",
              ])

          with open("docker-compose.override.yml", "w", encoding="utf-8") as f:
              f.write("\n".join(lines) + "\n")
          EOF
          echo "📄 docker-compose.override.yml generated"

