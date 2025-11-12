# Zitadel OIDC Service - Deployment Guide

## Описание

Этот проект содержит Docker Compose конфигурацию для развертывания Zitadel - полнофункционального OIDC провайдера с встроенной БД PostgreSQL.

## Требования

- Docker
- Docker Compose (v3.8+)
- 2GB свободной памяти минимум
- Открытые порты: 8080 (Zitadel), 5432 (PostgreSQL)

## Установка

### 1. Создание переменных окружения

Создайте файл `.env` в корне проекта:

```bash
# PostgreSQL Configuration
POSTGRES_DB=zitadel
POSTGRES_USER=zitadel
POSTGRES_PASSWORD=your_secure_password_here

# Zitadel Admin Configuration
ADMIN_USERNAME=admin@example.com
ADMIN_PASSWORD=YourSecurePassword@123

# Organization Configuration
ORG_NAME=MyOrganization

# External Configuration (для production)
ZITADEL_EXTERNALHOST=zitadel.example.com:8080
ZITADEL_EXTERNALSECURE=true

# TLS Configuration (enable для production)
TLS_ENABLED=false

# Logging level
ZITADEL_LOGLEVEL=info
```

### 2. Запуск сервиса

```bash
# Запустить все сервисы в фоне
docker-compose up -d

# Просмотр логов
docker-compose logs -f zitadel

# Проверка статуса
docker-compose ps
```

### 3. Первое подключение

Откройте в браузере: `http://localhost:8080`

Используйте учетные данные из `.env`:
- **Email**: admin@example.com
- **Password**: YourSecurePassword@123

## Конфигурация для Production

### 1. Обновите `.env` для Production:

```bash
ZITADEL_EXTERNALSECURE=true
ZITADEL_EXTERNALHOST=your-domain.com
TLS_ENABLED=true
ZITADEL_LOGLEVEL=warn
```

### 2. Используйте Coolify с reverse proxy (nginx)

Добавьте в `docker-compose.yml`:

```yaml
  nginx:
    image: nginx:alpine
    container_name: zitadel-nginx
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - zitadel
    networks:
      - zitadel_network
    restart: unless-stopped
```

### 3. Используйте Coolify для управления

В Coolify:
1. Создайте новый Service
2. Выберите "Docker Compose"
3. Загрузите файл `docker-compose.yml`
4. Установите переменные окружения
5. Нажмите "Deploy"

## Резервное копирование и восстановление

### Резервное копирование БД

```bash
docker-compose exec postgres pg_dump -U zitadel zitadel > backup.sql
```

### Восстановление БД

```bash
docker-compose exec -T postgres psql -U zitadel zitadel < backup.sql
```

## Остановка и удаление

```bash
# Остановить контейнеры
docker-compose down

# Остановить контейнеры и удалить все данные
docker-compose down -v
```

## Troubleshooting

### Контейнер не запускается

```bash
# Проверьте логи
docker-compose logs zitadel

# Проверьте доступность базы данных
docker-compose logs postgres
```

### Проблемы с подключением к БД

- Убедитесь, что PostgreSQL контейнер запущен
- Проверьте переменные окружения POSTGRES_*
- Перезагрузите оба контейнера

### Забыли пароль админа

1. Остановите контейнеры: `docker-compose down`
2. Удалите volume: `docker volume rm zitadel_postgres_data`
3. Измените пароль в `.env`
4. Перезапустите: `docker-compose up -d`

## Дополнительные ресурсы

- [Zitadel Documentation](https://zitadel.com/docs)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Coolify Documentation](https://coolify.io/docs)

## Поддерживаемые переменные окружения

| Переменная | Описание | По умолчанию |
|-----------|---------|-------------|
| POSTGRES_DB | Имя базы данных | zitadel |
| POSTGRES_USER | Пользователь БД | zitadel |
| POSTGRES_PASSWORD | Пароль БД | required |
| ADMIN_USERNAME | Email админа | admin@example.com |
| ADMIN_PASSWORD | Пароль админа | required |
| ORG_NAME | Название организации | MyOrganization |
| ZITADEL_EXTERNALHOST | Внешний хост | localhost:8080 |
| ZITADEL_EXTERNALSECURE | Использовать HTTPS | false |
| TLS_ENABLED | Включить TLS | false |
| ZITADEL_LOGLEVEL | Уровень логирования | info |

## Лицензия

Используйте в соответствии с лицензией Zitadel.

