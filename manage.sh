#!/bin/bash

# Zitadel Management Script
# Usage: ./manage.sh [command]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if .env exists
check_env() {
    if [ ! -f .env ]; then
        print_error ".env file not found!"
        echo "Please create .env file first. Example:"
        echo "  cp .env.prod .env"
        exit 1
    fi
}

# Commands
cmd_start() {
    print_header "Starting Zitadel Services"
    check_env
    docker-compose up -d
    print_success "Services started"
    echo ""
    echo "Access Zitadel at: http://localhost:8080"
}

cmd_stop() {
    print_header "Stopping Zitadel Services"
    docker-compose down
    print_success "Services stopped"
}

cmd_restart() {
    print_header "Restarting Zitadel Services"
    check_env
    cmd_stop
    sleep 2
    cmd_start
}

cmd_status() {
    print_header "Service Status"
    docker-compose ps
}

cmd_logs() {
    print_header "Zitadel Logs (last 50 lines)"
    docker-compose logs -f --tail=50 "$@"
}

cmd_backup() {
    print_header "Creating Database Backup"
    BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).sql.gz"
    docker-compose exec postgres pg_dump -U zitadel zitadel | gzip > "$BACKUP_FILE"
    print_success "Backup created: $BACKUP_FILE"
    ls -lh "$BACKUP_FILE"
}

cmd_restore() {
    if [ -z "$1" ]; then
        print_error "Restore file not specified"
        echo "Usage: $0 restore <backup-file>"
        echo "Example: $0 restore backup-20240101-120000.sql.gz"
        exit 1
    fi

    if [ ! -f "$1" ]; then
        print_error "Backup file not found: $1"
        exit 1
    fi

    print_header "Restoring from Backup"
    print_warning "This will restore database from: $1"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Restore cancelled"
        exit 1
    fi

    cmd_stop
    docker volume rm zitadel_postgres_data || true
    docker-compose up -d postgres
    sleep 10
    gunzip < "$1" | docker-compose exec -T postgres psql -U zitadel zitadel
    docker-compose up -d
    print_success "Database restored"
}

cmd_health() {
    print_header "Health Check"
    
    echo "PostgreSQL health:"
    docker-compose exec postgres pg_isready -U zitadel && print_success "PostgreSQL is healthy" || print_error "PostgreSQL is not responding"
    
    echo ""
    echo "Zitadel health:"
    docker-compose exec zitadel wget --quiet --tries=1 --spider http://localhost:8080/debug/livez && print_success "Zitadel is healthy" || print_error "Zitadel is not responding"
}

cmd_clean() {
    print_header "Cleaning Up"
    print_warning "This will remove all containers and volumes!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Cleanup cancelled"
        exit 1
    fi

    docker-compose down -v
    print_success "Cleaned up all containers and volumes"
}

cmd_logs_export() {
    print_header "Exporting Logs"
    LOG_FILE="logs-$(date +%Y%m%d-%H%M%S).txt"
    docker-compose logs > "$LOG_FILE"
    print_success "Logs exported to: $LOG_FILE"
}

cmd_update() {
    print_header "Updating Zitadel"
    check_env
    docker-compose pull
    docker-compose up -d
    print_success "Zitadel updated to latest version"
}

cmd_shell_postgres() {
    print_header "PostgreSQL Shell"
    docker-compose exec postgres psql -U zitadel zitadel
}

cmd_shell_zitadel() {
    print_header "Zitadel Shell"
    docker-compose exec zitadel sh
}

cmd_help() {
    cat << EOF
${BLUE}Zitadel Management Script${NC}

Usage: ./manage.sh [command] [options]

Commands:
  ${GREEN}start${NC}              Start all services
  ${GREEN}stop${NC}               Stop all services
  ${GREEN}restart${NC}            Restart all services
  ${GREEN}status${NC}             Show service status
  ${GREEN}logs${NC}               Show live logs (press Ctrl+C to exit)
  ${GREEN}logs [service]${NC}      Show logs for specific service (zitadel, postgres, nginx)
  ${GREEN}health${NC}             Check health of all services
  ${GREEN}backup${NC}             Create database backup
  ${GREEN}restore [file]${NC}      Restore from backup
  ${GREEN}update${NC}             Update Zitadel to latest version
  ${GREEN}clean${NC}              Remove all containers and volumes (careful!)
  ${GREEN}export-logs${NC}        Export all logs to file
  ${GREEN}shell-pg${NC}           Open PostgreSQL shell
  ${GREEN}shell-zitadel${NC}      Open Zitadel shell
  ${GREEN}help${NC}               Show this help message

Examples:
  ./manage.sh start
  ./manage.sh logs
  ./manage.sh logs zitadel
  ./manage.sh backup
  ./manage.sh restore backup-20240101-120000.sql.gz

${BLUE}For production use, consider using Coolify for management.${NC}

EOF
}

# Main
case "${1:-help}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs "${@:2}"
        ;;
    backup)
        cmd_backup
        ;;
    restore)
        cmd_restore "$2"
        ;;
    health)
        cmd_health
        ;;
    clean)
        cmd_clean
        ;;
    export-logs)
        cmd_logs_export
        ;;
    update)
        cmd_update
        ;;
    shell-pg)
        cmd_shell_postgres
        ;;
    shell-zitadel)
        cmd_shell_zitadel
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        print_error "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac

