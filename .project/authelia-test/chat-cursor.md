> sonnet 4.5

### 1. docker-compose файл в проекте

- Coolify использует docker-compose как "единственный источник истины"
- Все настройки (volumes, networks, environment) должны быть в compose файле
- Coolify автоматически обнаружит переменные окружения и покажет их в UI
- Вы сможете редактировать переменные в Coolify UI, но структура берётся из compose

### 2. GitHub → Coolify интеграция

Полная структура проекта, которую нужно создать:

## Структура проекта для GitHub:

```
authelia-coolify/
├── docker-compose.yml          # Основной файл для Coolify
├── config/
│   ├── configuration.yml       # Главный конфиг Authelia
│   └── users.yml              # Файл пользователей (опционально)
├── secrets/                    # Папка для секретов (создаётся автоматически)
│   ├── .gitkeep               # Чтобы Git отслеживал папку
│   └── .gitignore             # Игнорировать содержимое секретов
└── README.md                   # Инструкции по деплою
```

## Оптимизированный docker-compose.yml для Coolify:

Создам вам готовый файл, адаптированный под Coolify с учётом документации:

```yaml
services:
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    restart: unless-stopped
    
    # Coolify автоматически создаст сеть и добавит прокси
    # Не нужно указывать networks вручную
    
    volumes:
      # Используем bind volumes с относительными путями
      - type: bind
        source: ./config
        target: /config
        is_directory: true
      
      - type: bind
        source: ./secrets
        target: /secrets
        is_directory: true
        read_only: true
    
    environment:
      # Timezone
      - TZ=${TZ:-Europe/Moscow}
      
      # Секреты через файлы (Coolify создаст их автоматически)
      - AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE=/secrets/JWT_SECRET
      - AUTHELIA_SESSION_SECRET_FILE=/secrets/SESSION_SECRET
      - AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE=/secrets/STORAGE_ENCRYPTION_KEY
      
      # Magic environment variables для Coolify
      # Coolify автоматически сгенерирует URL на основе вашего wildcard домена
      - SERVICE_FQDN_AUTHELIA_9091
      
      # Опциональные переменные с дефолтными значениями
      - LOG_LEVEL=${LOG_LEVEL:-info}
      - AUTHELIA_SERVER_ADDRESS=${AUTHELIA_SERVER_ADDRESS:-tcp://0.0.0.0:9091}
    
    labels:
      # Traefik labels для Coolify
      - traefik.enable=true
      - traefik.http.routers.authelia.rule=Host(`${AUTHELIA_DOMAIN}`)
      - traefik.http.routers.authelia.entrypoints=https
      - traefik.http.routers.authelia.tls=true
      - traefik.http.services.authelia.loadbalancer.server.port=9091
      
      # ForwardAuth middleware для защиты других сервисов
      - traefik.http.middlewares.authelia.forwardAuth.address=http://authelia:9091/api/verify?rd=https://${AUTHELIA_DOMAIN}
      - traefik.http.middlewares.authelia.forwardAuth.trustForwardHeader=true
      - traefik.http.middlewares.authelia.forwardAuth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email
    
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9091/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Минимальный config/configuration.yml:

```yaml
---
server:
  address: 'tcp://0.0.0.0:9091'

log:
  level: 'info'
  format: 'text'

theme: 'dark'

default_redirection_url: 'https://auth.yourdomain.com'

totp:
  issuer: 'yourdomain.com'
  period: 30
  skew: 1

authentication_backend:
  file:
    path: '/config/users.yml'
    password:
      algorithm: 'argon2'
      argon2:
        variant: 'argon2id'
        iterations: 3
        memory: 65536
        parallelism: 4
        key_length: 32
        salt_length: 16

access_control:
  default_policy: 'deny'
  rules:
    - domain: '*.yourdomain.com'
      policy: 'two_factor'

session:
  name: 'authelia_session'
  expiration: 14400  # 4 hours
  inactivity: 14400  # 4 hours
  domain: 'yourdomain.com'

regulation:
  max_retries: 3
  find_time: 120
  ban_time: 300

storage:
  local:
    path: '/config/db.sqlite3'

notifier:
  filesystem:
    filename: '/config/notification.txt'
```

## Файл .gitignore для secrets/:

```
# Игнорировать все файлы секретов
*

# Но отслеживать саму папку
!.gitkeep
```

## Важные моменты для Coolify:

### В Coolify UI вам нужно будет:

1. **Добавить Environment Variables:**
   ```
   TZ=Europe/Moscow
   AUTHELIA_DOMAIN=auth.yourdomain.com
   LOG_LEVEL=info
   ```

2. **Создать секреты** (в разделе Environment Variables):
   ```bash
   # Сгенерируйте локально и добавьте в Coolify:
   JWT_SECRET=<64 случайных символа>
   SESSION_SECRET=<64 случайных символа>
   STORAGE_ENCRYPTION_KEY=<64 случайных символа>
   ```

3. **Назначить домен** в Coolify UI:
   - Coolify найдёт сервис `authelia` и предложит назначить домен
   - Укажите: `auth.yourdomain.com:9091`

### Преимущества такой структуры:

✅ **Один источник истины** - все изменения в GitHub  
✅ **Простой redeploy** - просто нажимаете кнопку в Coolify  
✅ **Переменные в UI** - можно менять без коммита  
✅ **Секреты защищены** - не попадают в Git  
✅ **Traefik интеграция** - автоматическая через labels  
✅ **Healthchecks** - Coolify будет мониторить состояние  

### Workflow:

1. **Создаёте репозиторий** на GitHub с этой структурой
2. **В Coolify**: Add Resource → Docker Compose → указываете URL репозитория
3. **Настраиваете** Environment Variables в Coolify UI
4. **Deploy** - Coolify подтянет compose и развернёт
5. **Изменения** - редактируете файлы в GitHub → Redeploy в Coolify

========================================

[9 tools called]

Отлично! Я создал полную структуру проекта для развертывания Authelia в Coolify. Вот что было создано:

## 📁 Созданная структура проекта:

```
E:\_@Go\@OIDC\
├── docker-compose.yml              ✅ Основной файл с Magic Variables
├── config/
│   ├── configuration.yml           ✅ Конфигурация Authelia
│   └── users.yml                   ✅ База пользователей
├── secrets/
│   ├── .gitkeep                    ✅ Для отслеживания папки в Git
│   └── .gitignore                  ✅ Игнорирование секретов
├── .gitignore                      ✅ Игнорирование runtime файлов
├── README.md                       ✅ Полная документация
└── COOLIFY_SETUP.md               ✅ Пошаговая инструкция на русском
```

## 🎯 Ключевые особенности реализации:

### 1. **Magic Variables в docker-compose.yml:**

```yaml
environment:
  # Автогенерация секретов (64 символа)
  - AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET=${SERVICE_PASSWORD_64_JWT}
  - AUTHELIA_SESSION_SECRET=${SERVICE_PASSWORD_64_SESSION}
  - AUTHELIA_STORAGE_ENCRYPTION_KEY=${SERVICE_PASSWORD_64_STORAGE}
  
  # Автогенерация доменов
  - SERVICE_FQDN_AUTHELIA_9091
  - AUTHELIA_PUBLIC_URL=${SERVICE_URL_AUTHELIA_9091}
  - AUTHELIA_DOMAIN=${SERVICE_FQDN_AUTHELIA}
```

### 2. **Traefik Labels для автоматической интеграции:**

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.authelia.rule=Host(`${SERVICE_FQDN_AUTHELIA}`)
  - traefik.http.middlewares.authelia.forwardAuth.address=http://authelia:9091/api/verify?rd=https://${SERVICE_FQDN_AUTHELIA}
```

### 3. **Healthcheck для мониторинга:**

```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9091/api/health"]
  interval: 30s
```

### 4. **Пример защищенного сервиса (закомментирован):**

В `docker-compose.yml` есть пример `whoami` сервиса, который можно раскомментировать для тестирования.

## 🚀 Что делать дальше:

### Шаг 1: Закоммитьте в Git

```bash
git add .
git commit -m "Add Authelia configuration for Coolify deployment"
git push
```

### Шаг 2: В Coolify

1. **Add Resource** → **Docker Compose**
2. **Repository URL**: ваш GitHub репозиторий
3. **Environment Variables** добавьте только:
   ```
   ROOT_DOMAIN=yourdomain.com
   TZ=Europe/Moscow
   ```
4. **Deploy**

### Шаг 3: Coolify автоматически:

- ✅ Сгенерирует `SERVICE_PASSWORD_64_JWT`
- ✅ Сгенерирует `SERVICE_PASSWORD_64_SESSION`
- ✅ Сгенерирует `SERVICE_PASSWORD_64_STORAGE`
- ✅ Создаст `SERVICE_FQDN_AUTHELIA` (например, `authelia-abc123.yourdomain.com`)
- ✅ Настроит Traefik с SSL
- ✅ Запустит контейнер

## 📖 Документация:

- **README.md** - полная документация на английском (для GitHub)
- **COOLIFY_SETUP.md** - детальная пошаговая инструкция на русском

## 🔐 Дефолтные credentials:

```
Username: admin
Password: authelia
```

**⚠️ Обязательно смените после первого входа!**

## 💡 Дополнительные возможности:

1. **Защита других сервисов** - просто добавьте label:
   ```yaml
   - traefik.http.routers.your-service.middlewares=authelia@docker
   ```

2. **OIDC для SSO** - раскомментируйте секцию в `config/configuration.yml`

3. **PostgreSQL вместо SQLite** - добавьте сервис в docker-compose

4. **Email уведомления** - настройте SMTP в конфигурации

Всё готово к деплою! Есть вопросы по какой-то части конфигурации? 🚀