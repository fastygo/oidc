# Go Fast CMS - A Lightweight CRUD Example

## 🔐 Zitadel OIDC Starter

This project now includes a **complete production-ready Docker Compose setup** for deploying **Zitadel**, a powerful OpenID Connect (OIDC) provider. This enables:

*   **Centralized Authentication:** Use Zitadel as your OIDC provider for user authentication
*   **Easy Integration:** Connect multiple applications to a single identity provider
*   **Production Ready:** Includes PostgreSQL, nginx reverse proxy, and best practices configuration
*   **Development & Production:** Separate configurations for development and production environments
*   **Full Documentation:** Complete guides and examples in Russian
*   **Management Tools:** Backup, restore, monitoring, and health checks

### ⚡ Quick Start (5 minutes)

```bash
# Create .env file
cat > .env << 'EOF'
POSTGRES_PASSWORD=SecurePass2024!
ADMIN_USERNAME=admin@example.com
ADMIN_PASSWORD=AdminPass2024!
ORG_NAME=MyOrganization
ZITADEL_EXTERNALHOST=localhost:8080
ZITADEL_EXTERNALSECURE=false
EOF

# Start services
docker-compose up -d

# Access at http://localhost:8080
# Login: admin@example.com / AdminPass2024!
```

### 📚 Documentation (Start Here)

1. **[GETTING_STARTED.md](GETTING_STARTED.md)** ← **Begin here!** (10 min)
2. **[INDEX.md](INDEX.md)** - Complete file index and recommendations
3. **[ZITADEL_SETUP_SUMMARY.md](ZITADEL_SETUP_SUMMARY.md)** - Project overview
4. **[QUICKSTART.md](QUICKSTART.md)** - Quick commands and operations
5. **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide
6. **[OIDC_GUIDE.md](OIDC_GUIDE.md)** - OIDC integration with code examples
7. **[PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md)** - Pre-production checklist
8. **[COMMANDS_CHEATSHEET.md](COMMANDS_CHEATSHEET.md)** - Command reference

### 📦 Files Included

**Docker Compose:**
*   `docker-compose.yml` - Development configuration
*   `docker-compose.prod.yml` - Production configuration with nginx
*   `nginx.conf.example` - Nginx reverse proxy configuration

**Management:**
*   `manage.sh` - Management script (backup, restore, monitoring, logs, health)
*   `env.development` - Development environment example
*   `env.production` - Production environment example

**Documentation:**
*   Complete guides in Russian (~150 KB)
*   OIDC integration examples (Node.js, React, Python, Go)
*   Production-ready checklist
*   Command reference guide
