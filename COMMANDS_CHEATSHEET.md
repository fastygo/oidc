# 🚀 Zitadel Commands Cheatsheet

## ⚡ Quick Commands

### Start/Stop/Restart
```bash
# Start all services
./manage.sh start
docker-compose up -d

# Stop all services
./manage.sh stop
docker-compose down

# Restart all services
./manage.sh restart
docker-compose restart

# View status
./manage.sh status
docker-compose ps
```

### Logs
```bash
# View logs (all services)
./manage.sh logs
docker-compose logs -f

# View specific service logs
./manage.sh logs zitadel
docker-compose logs -f zitadel

# View last 50 lines
./manage.sh logs --tail=50
docker-compose logs --tail=50

# View logs for postgres
./manage.sh logs postgres
docker-compose logs -f postgres

# Export all logs
./manage.sh export-logs
docker-compose logs > logs-$(date +%Y%m%d-%H%M%S).txt
```

### Health & Status
```bash
# Check health of all services
./manage.sh health

# Check container stats
docker stats

# Check service status with details
docker-compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
```

---

## 💾 Backup & Restore

### Backup Operations
```bash
# Quick backup
./manage.sh backup
docker-compose exec postgres pg_dump -U zitadel zitadel | gzip > backup-$(date +%Y%m%d).sql.gz

# List backups
ls -lh backup-*.sql.gz

# Check backup size
du -sh backup-*.sql.gz

# Backup to specific location
docker-compose exec postgres pg_dump -U zitadel zitadel | gzip > /mnt/backups/backup-$(date +%Y%m%d).sql.gz
```

### Restore Operations
```bash
# Restore from backup
./manage.sh restore backup-20240101-120000.sql.gz

# Manual restore
docker-compose down
docker volume rm zitadel_postgres_data
docker-compose up -d postgres
sleep 10
gunzip < backup-20240101-120000.sql.gz | docker-compose exec -T postgres psql -U zitadel zitadel
docker-compose up -d
```

### Automated Backup (Cron)
```bash
# Edit crontab
crontab -e

# Add this line (daily at 2 AM)
0 2 * * * cd /opt/zitadel && ./manage.sh backup >> /var/log/zitadel-backup.log 2>&1

# Add this line (weekly cleanup - keep only last 4 backups)
0 3 * * 0 cd /opt/zitadel && ls -t backup-*.sql.gz | tail -n +5 | xargs -r rm
```

---

## 🔄 Update & Maintenance

### Update Zitadel
```bash
# Pull latest image
docker-compose pull

# Restart with new image
docker-compose up -d

# Check logs after update
./manage.sh logs -f --tail=100 zitadel

# Rollback to previous version (if needed)
docker-compose pull ghcr.io/zitadel/zitadel:v2.XX.X
```

### Database Maintenance
```bash
# Connect to PostgreSQL shell
./manage.sh shell-pg
docker-compose exec postgres psql -U zitadel -d zitadel

# Inside psql:
-- Check database size
SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) 
FROM pg_database 
WHERE datname = 'zitadel';

-- Check table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
FROM pg_tables 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Run VACUUM
VACUUM ANALYZE;

-- Exit
\q
```

---

## 🔧 Troubleshooting Commands

### Check Container Health
```bash
# Zitadel health
docker-compose exec zitadel wget --spider http://localhost:8080/debug/livez

# PostgreSQL health
./manage.sh health

# View detailed health info
docker-compose exec zitadel curl -s http://localhost:8080/debug/readyz

# Check Zitadel version
docker-compose exec zitadel sh -c 'echo "Version info in logs"'
docker-compose logs zitadel | grep -i version
```

### Debug Commands
```bash
# Shell into Zitadel container
./manage.sh shell-zitadel
docker-compose exec zitadel sh

# Shell into PostgreSQL container
./manage.sh shell-postgres
docker-compose exec postgres sh

# Check network connectivity
docker-compose exec zitadel ping postgres
docker-compose exec postgres ping zitadel

# Check DNS resolution
docker-compose exec zitadel nslookup postgres

# View container details
docker inspect <container_id>
docker inspect zitadel-app
```

### Disk Space & Cleanup
```bash
# Check docker disk usage
docker system df

# Check zitadel volumes
du -sh zitadel_*

# Cleanup unused images
docker image prune -a

# Cleanup unused networks
docker network prune

# Cleanup unused volumes (CAREFUL!)
docker volume prune

# Remove everything (DANGER!)
./manage.sh clean
```

---

## 📊 Database Commands

### PostgreSQL Queries
```bash
# Connect to database
docker-compose exec postgres psql -U zitadel -d zitadel

# List tables
\dt

# Check user count
SELECT COUNT(*) as user_count FROM users;

# List users
SELECT id, user_name, email FROM users LIMIT 10;

# Check organizations
SELECT id, name FROM orgs;

# Check sessions
SELECT COUNT(*) as session_count FROM sessions WHERE expires_at > NOW();

# Export data to CSV
\COPY users TO 'users.csv' WITH CSV HEADER;

# Check connections
SELECT datname, usename, count(*) FROM pg_stat_activity GROUP BY datname, usename;
```

---

## 🌐 Docker Network & Port Commands

### Port Management
```bash
# Check which ports are in use
netstat -tlnp | grep 8080
netstat -tlnp | grep 5432

# Check specific port
lsof -i :8080
lsof -i :5432

# Change port mapping (edit docker-compose.yml)
# Before: - "8080:8080"
# After: - "8090:8080"
docker-compose up -d
```

### Network Debugging
```bash
# List docker networks
docker network ls

# Inspect docker network
docker network inspect zitadel_network

# Check network connectivity
docker-compose exec zitadel ping postgres
docker-compose exec zitadel curl http://postgres:5432

# DNS resolution test
docker-compose exec zitadel cat /etc/hosts
```

---

## 🔐 Security & Secrets

### Password Management
```bash
# Generate strong password
openssl rand -base64 32

# Generate UUID for user ID
uuidgen

# Check .env permissions
ls -la .env

# Secure .env file
chmod 600 .env

# Rotate database password (in production)
# 1. Update .env with new password
# 2. Restart services
# 3. Update client applications
```

### SSL/TLS Commands
```bash
# Check certificate expiry
echo | openssl s_client -servername zitadel.yourdomain.com -connect localhost:443 2>/dev/null | openssl x509 -noout -dates

# Check certificate details
openssl x509 -in certs/cert.pem -text -noout

# Generate self-signed cert (development only)
openssl req -x509 -newkey rsa:4096 -keyout certs/key.pem -out certs/cert.pem -days 365 -nodes
```

---

## 📈 Performance & Monitoring

### Monitor Resources
```bash
# Real-time monitoring
docker stats

# CPU usage
docker stats --no-stream | grep zitadel

# Memory usage
docker stats --no-stream | awk '{print $1, $4, $6}'

# Container resource limits
docker inspect zitadel-app --format='{{json .HostConfig.MemorySwap}}'
```

### Performance Tuning
```bash
# Check query performance (in PostgreSQL)
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

# Check slow queries
SELECT query, mean_time 
FROM pg_stat_statements 
WHERE mean_time > 100 
ORDER BY mean_time DESC;
```

---

## 🚀 Production Commands

### Production Monitoring
```bash
# Check production services
docker-compose -f docker-compose.prod.yml ps

# View production logs
docker-compose -f docker-compose.prod.yml logs -f

# Backup production database
docker-compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U zitadel zitadel | gzip > backup-prod-$(date +%Y%m%d).sql.gz
```

### Zero-Downtime Deployment
```bash
# Update with no downtime
docker-compose pull
docker-compose up -d --no-deps --build zitadel

# Verify health
./manage.sh health

# Check logs
docker-compose logs -f zitadel
```

---

## 📝 Useful Aliases

Add to `.bashrc` or `.zshrc`:

```bash
# Zitadel shortcuts
alias zit-start='cd /opt/zitadel && docker-compose up -d'
alias zit-stop='cd /opt/zitadel && docker-compose down'
alias zit-logs='cd /opt/zitadel && docker-compose logs -f'
alias zit-backup='cd /opt/zitadel && ./manage.sh backup'
alias zit-health='cd /opt/zitadel && ./manage.sh health'
alias zit-status='cd /opt/zitadel && docker-compose ps'

# Database shortcuts
alias pg-shell='cd /opt/zitadel && ./manage.sh shell-pg'
alias pg-backup='cd /opt/zitadel && ./manage.sh backup'

# Docker shortcuts
alias docker-clean='docker system prune -a --volumes -f'
alias docker-stats='docker stats --no-stream'
```

---

## 🔔 Monitoring Script

Create `monitor.sh`:

```bash
#!/bin/bash
while true; do
  clear
  echo "=== Zitadel Monitoring ==="
  echo "Time: $(date)"
  echo ""
  echo "Services:"
  docker-compose ps
  echo ""
  echo "Resource Usage:"
  docker stats --no-stream
  echo ""
  echo "Recent Logs:"
  docker-compose logs --tail=5 zitadel
  sleep 10
done
```

Run: `chmod +x monitor.sh && ./monitor.sh`

---

## 🆘 Emergency Commands

### Service Recovery
```bash
# Kill stuck container
docker-compose kill zitadel

# Force remove container
docker-compose rm -f zitadel

# Restart in debug mode
docker-compose up zitadel (without -d)

# View real-time container output
docker attach zitadel-app
```

### Data Recovery
```bash
# Last resort: restore from backup
./manage.sh stop
docker volume rm zitadel_postgres_data
./manage.sh restore backup-latest.sql.gz
```

---

## 📞 Support Commands

```bash
# Collect diagnostics
echo "=== System Info ===" && uname -a
echo "=== Docker Info ===" && docker version
echo "=== Services ===" && docker-compose ps
echo "=== Logs ===" && docker-compose logs --tail=50
echo "=== Disk ===" && df -h
```

---

**Last Updated**: 2024-11-12
**Version**: 1.0

