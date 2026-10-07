# Description
Self-hosted Forgejo (Git server) running in Docker with PostgreSQL. Repositories stored in /srv/repo, config/data in /srv/forgejo/data. Includes automated backup/restore and update scripts.

# Installation steps
## preparation
1. debian 13 with working docker
2. /srv volume with enough space

## copy files
1. mkdir -p /srv/forgejo
2. copy .env to /srv/forgejo
3. copy docker-compose.yaml to /srv/forgejo
4. copy docker-update.sh to /srv/forgejo
5. chmod +x /srv/forgejo/docker-update.sh

## Configure .env (REQUIRED before first start)
Edit /srv/forgejo/.env and set:
- DB_PASSWD: generate with `openssl rand -base64 32`
- SERVER_NAME: your server's hostname or IP (e.g. 192.168.1.10)
- ROOT_URL: must match how users access Forgejo (e.g. http://192.168.1.10:3000/)
- DISABLE_REGISTRATION: leave false for now, set true after setup

SERVER_NAME must be the hostname part of ROOT_URL (e.g. ROOT_URL=http://192.168.1.10:3000/ → SERVER_NAME=192.168.1.10). Mismatch breaks clone URLs.

Lock down .env permissions (contains DB password):
```shell
chmod 600 /srv/forgejo/.env
```

Verify config resolves correctly:
```shell
cd /srv/forgejo && docker compose config
```

## Directory Permissions (Critical)
Forgejo runs as UID 1000. If ./data/forgejo doesn't exist, Docker creates it as root, and Forgejo can't write to it.
mkdir -p /srv/forgejo/data/forgejo
mkdir -p /srv/forgejo/data/postgres
chown -R 1000:1000 /srv/forgejo/data/forgejo
chown -R 999:999 /srv/forgejo/data/postgres   # postgres container UID

## /srv/repo Permissions
mkdir -p /srv/repo
chown -R 1000:1000 /srv/repo

## Firewall Rules
Ports 3000 (HTTP) and 2222 (SSH) must be open:
```shell
apt install ufw   # skip if already installed
ufw allow 3000/tcp
ufw allow 2222/tcp
ufw enable
```

## start container
```shell
cd /srv/forgejo && ./docker-update.sh
```

## configure forgejo
After docker-update.sh:
1. Open http://your-server:3000 (or whatever ROOT_URL you set)
2. Complete the install wizard (admin account, etc.)
3. Create organizations/users for your team
4. Set up SSH keys for git access
5. Lock down registration: edit .env, set DISABLE_REGISTRATION=true, then:
```shell
cd /srv/forgejo && docker compose up -d
```

# Backup Strategy
Make sure /srv/forgejo/backups/ exists first:
```shell
mkdir -p /srv/forgejo/backups
```

Add a cron job (DB dump + filesystem backup with retention). Adjust `-U sph sph-forgejo` if you changed POSTGRES_USER/POSTGRES_DB in .env:
```shell
(crontab -l 2>/dev/null; echo "0 2 * * * cd /srv/forgejo && docker compose exec -T postgres pg_dump -U sph sph-forgejo > /srv/forgejo/backups/db-\$(date +\%F).sql && tar czf /srv/forgejo/backups/fs-\$(date +\%F).tar.gz -C /srv repo && tar czf /srv/forgejo/backups/forgejo-data-\$(date +\%F).tar.gz -C /srv/forgejo data/forgejo && find /srv/forgejo/backups -mtime +14 -delete") | crontab -
```

# Restore from backup
```shell
# Stop Forgejo
cd /srv/forgejo && docker compose stop forgejo

# Restore database
docker compose exec -T postgres psql -U sph -d sph-forgejo < /srv/forgejo/backups/db-YYYY-MM-DD.sql

# Restore repositories
tar xzf /srv/forgejo/backups/fs-YYYY-MM-DD.tar.gz -C /srv

# Restore Forgejo data (avatars, attachments, config)
tar xzf /srv/forgejo/backups/forgejo-data-YYYY-MM-DD.tar.gz -C /srv/forgejo

# Fix permissions and start
chown -R 1000:1000 /srv/repo /srv/forgejo/data/forgejo
cd /srv/forgejo && docker compose start forgejo
```

# Updating
Before updating, take a manual backup:
```shell
cd /srv/forgejo && docker compose exec -T postgres pg_dump -U sph sph-forgejo > /srv/forgejo/backups/db-manual-$(date +%F).sql
```
Then run:
```shell
cd /srv/forgejo && ./docker-update.sh
```
