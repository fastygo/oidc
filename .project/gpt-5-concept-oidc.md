## Интранет и Coolify-Like подход

### Что сделаем
- Добавим отдельный стек `docker-compose.apisix.yml` для APISIX с Traefik-лейблами и автозагрузкой роутов без редактирования файлов внутри контейнера.
- Переведём Kratos на “безфайловую” конфигурацию через переменные окружения (всё задаётся из интерфейса Coolify), чтобы не трогать `configs/kratos.yml`.

### 1) APISIX для шины запросов (Traefik -> APISIX -> внутренняя сеть)

Создайте файл `docker-compose.apisix.yml`:

```yaml
version: '3.8'

services:
  etcd:
    image: bitnami/etcd:3.5
    environment:
      ALLOW_NONE_AUTHENTICATION: "yes"
      ETCD_ENABLE_V2: "false"
      ETCD_ADVERTISE_CLIENT_URLS: http://etcd:2379
      ETCD_LISTEN_CLIENT_URLS: http://0.0.0.0:2379
    volumes:
      - etcd_data:/bitnami/etcd
    healthcheck:
      test: ["CMD-SHELL", "etcdctl --endpoints=http://localhost:2379 endpoint health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - intranet

  apisix:
    image: apache/apisix:3.8.0-debian
    depends_on:
      - etcd
    environment:
      # Минимальный config.yaml через переменную окружения (без монтирования файла)
      APISIX_CONFIG: |
        apisix:
          node_listen: 9080
          enable_admin: true
          admin_key:
            - name: admin
              key: ${APISIX_ADMIN_KEY:-edd1c9f034335f136f87ad84b625c8f1}
              role: admin
        deployment:
          role: data_plane
          role_data_plane:
            config_provider: etcd
        etcd:
          host:
            - "http://etcd:2379"
          prefix: "/apisix"
          timeout: 30
    command:
      - /bin/sh
      - -c
      - |
        printf "%s" "$APISIX_CONFIG" > /usr/local/apisix/conf/config.yaml \
          && /docker-entrypoint.sh docker-start
    networks:
      - intranet
    labels:
      - traefik.enable=true
      - traefik.http.routers.apisix.entryPoints=websecure
      - traefik.http.routers.apisix.rule=Host(`auth.app-server.ru`)
      - traefik.http.routers.apisix.tls=true
      - traefik.http.services.apisix.loadbalancer.server.port=9080

  apisix-init:
    image: curlimages/curl:8.10.1
    depends_on:
      - apisix
    environment:
      APISIX_ADMIN: http://apisix:9180
      APISIX_ADMIN_KEY: ${APISIX_ADMIN_KEY:-edd1c9f034335f136f87ad84b625c8f1}
    command:
      - /bin/sh
      - -c
      - |
        set -e

        wait() {
          for i in $(seq 1 30); do
            if curl -fsS "${APISIX_ADMIN}/apisix/admin/routes" -H "X-API-KEY: ${APISIX_ADMIN_KEY}" >/dev/null 2>&1; then
              exit 0
            fi
            sleep 2
          done
          echo "APISIX Admin API not ready" >&2
          exit 1
        }

        mkroute() {
          id="$1"; uri="$2"; upstream="$3"; port="$4"
          curl -fsS -X PUT "${APISIX_ADMIN}/apisix/admin/routes/${id}" \
            -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
            -H "Content-Type: application/json" \
            -d "{
              \"uri\": \"${uri}\",
              \"upstream\": { \"type\": \"roundrobin\", \"nodes\": { \"${upstream}:${port}\": 1 } },
              \"plugins\": {
                \"proxy-rewrite\": {
                  \"headers\": { \"X-Forwarded-Proto\": \"https\" }
                }
              }
            }"
          echo
        }

        wait

        # Hydra (OIDC): /.well-known/* и /oauth2/*
        mkroute hydra-well-known \"/.well-known/*\" hydra 4444
        mkroute hydra-oauth2   \"/oauth2/*\"       hydra 4444

        # Kratos (public): /self-service/* /sessions/* /identities/*
        mkroute kratos-self-service \"/self-service/*\" kratos 4433
        mkroute kratos-sessions     \"/sessions/*\"      kratos 4433
        mkroute kratos-identities   \"/identities/*\"    kratos 4433

        echo \"APISIX routes applied\"
        sleep 3600
    networks:
      - intranet

networks:
  intranet:
    external: true

volumes:
  etcd_data:
```

- В Coolify задайте только переменную `APISIX_ADMIN_KEY` (если хотите не дефолтный ключ).
- Traefik слушает домен `auth.app-server.ru` и проксирует всё на APISIX:9080.
- APISIX через init-контейнер автоматически создаёт нужные маршруты на Hydra и Kratos (внутренняя сеть `intranet`). Никаких ручных файлов и терминала.

Важно:
- Гарантируйте, что `hydra` и `kratos` работают в той же сети `intranet` и имеют имена сервисов именно `hydra` и `kratos`, либо скорректируйте апстримы в скрипте.

---

### 2) Kratos без kratos.yml — только через переменные окружения

В `docker-compose.identity.yml` замените сервис `kratos` на вариант без конфигурационного файла:

```yaml
  kratos:
    image: oryd/kratos:v1.3.1
    depends_on:
      - kratos-pg
    environment:
      # DB
      DSN: postgres://${KRATOS_DB_USER:-kratos}:${KRATOS_DB_PASSWORD:?}@kratos-pg:5432/${KRATOS_DB_NAME:-kratos}?sslmode=disable&max_conns=20&max_idle_conns=4
      LOG_LEVEL: info

      # Serve
      SERVE_PUBLIC_BASE_URL: https://${IDENTITY_DOMAIN:?}          # напр. identity.app-server.ru (если публикуете напрямик)
      SERVE_ADMIN_BASE_URL: http://kratos:4434

      # Self-Service
      SELFSERVICE_DEFAULT_BROWSER_RETURN_URL: https://${IDENTITY_DOMAIN:?}/
      SELFSERVICE_FLOWS_LOGIN_UI_URL: https://${IDENTITY_DOMAIN:?}/
      SELFSERVICE_FLOWS_REGISTRATION_UI_URL: https://${IDENTITY_DOMAIN:?}/
      SELFSERVICE_FLOWS_SETTINGS_UI_URL: https://${IDENTITY_DOMAIN:?}/
      SELFSERVICE_FLOWS_RECOVERY_ENABLED: "true"
      SELFSERVICE_FLOWS_RECOVERY_UI_URL: https://${IDENTITY_DOMAIN:?}/
      SELFSERVICE_FLOWS_VERIFICATION_ENABLED: "true"
      SELFSERVICE_FLOWS_VERIFICATION_UI_URL: https://${IDENTITY_DOMAIN:?}/

      # Mail (на проде замените на реальный SMTP URI)
      COURIER_SMTP_CONNECTION_URI: noop://
    command: serve --dev --watch-courier
    networks:
      - intranet
```

- Все значения удобно редактировать прямо в Coolify → Environment Variables (без файлов и терминала).
- Если вы публикуете Kratos только через APISIX, `IDENTITY_DOMAIN` можно не трогать (Kratos public URL всё равно будет за APISIX). Главное — маршруты в APISIX уже настроены.

---

### Проверка связки
- Hydra:
  - Переменные в `docker-compose.oidc-provider.yml` должны содержать корректный `URLS_SELF_ISSUER=https://auth.app-server.ru`.
  - Логин/Consent:
    - Для быстрого старта можно использовать демо-приложение `hydra-login-consent` (оно уже заложено в compose).
    - На проде лучше указывать на ваш UI или Kratos UI endpoints.

- APISIX:
  - `https://auth.app-server.ru/.well-known/openid-configuration` → должен отвечать Hydra (через APISIX).
  - `https://auth.app-server.ru/self-service/flows` → должен отвечать Kratos (через APISIX).

Если нужно, добавлю/подправлю:
- Именование сети/сервисов под ваш проект.
- Дополнительные роуты и плагины APISIX (rate limit, auth, rewrite и т.д.).
- Лейблы Traefik под другой entrypoint (например, `websecure` у вас уже учтён).

================================

# Предварительная версия (Было)

Реализуем чёткий разнос на два независимых сервиса ORY, рассчитанный на Coolify + Traefik, с APISIX в роли единственного внешнего шлюза. Идея: APISIX публикуется наружу через Traefik; Hydra и Kratos доступны только во внутренней сети intranet, куда APISIX проксирует.

### Файл 1: docker-compose.oidc-provider.yml (OIDC провайдер — ORY Hydra)

```yaml
version: '3.8'

services:
  hydra-pg:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: ${HYDRA_DB_USER:-hydra}
      POSTGRES_PASSWORD: ${HYDRA_DB_PASSWORD:?}
      POSTGRES_DB: ${HYDRA_DB_NAME:-hydra}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${HYDRA_DB_USER:-hydra}"]
      interval: 10s
      timeout: 30s
      retries: 5
    volumes:
      - hydra_pg_data:/var/lib/postgresql/data
    networks:
      - intranet

  hydra-migrate:
    image: oryd/hydra:v2.3.0
    depends_on:
      - hydra-pg
    environment:
      DSN: postgres://${HYDRA_DB_USER:-hydra}:${HYDRA_DB_PASSWORD:?}@hydra-pg:5432/${HYDRA_DB_NAME:-hydra}?sslmode=disable
    command: migrate sql -e --yes
    restart: on-failure
    networks:
      - intranet

  hydra:
    image: oryd/hydra:v2.3.0
    depends_on:
      - hydra-migrate
    environment:
      DSN: postgres://${HYDRA_DB_USER:-hydra}:${HYDRA_DB_PASSWORD:?}@hydra-pg:5432/${HYDRA_DB_NAME:-hydra}?sslmode=disable
      LOG_LEVEL: info
      # Публичная/админ-службы без TLS, TLS завершается на APISIX/Traefik
      SERVE_PUBLIC_TLS_ENABLED: "false"
      SERVE_ADMIN_TLS_ENABLED: "false"
      SERVE_PUBLIC_PORT: "4444"
      SERVE_ADMIN_PORT: "4445"
      # ВАЖНО: Укажите публичный Issuer (домен APISIX)
      URLS_SELF_ISSUER: https://${OIDC_ISSUER_DOMAIN:?}
      # Вариант A (dev): встроенное демо Login/Consent-приложение
      URLS_LOGIN: https://${OIDC_ISSUER_DOMAIN:?}/login
      URLS_CONSENT: https://${OIDC_ISSUER_DOMAIN:?}/consent
      # Секрет для подписи (задайте через Coolify)
      SECRETS_SYSTEM: ${HYDRA_SECRETS_SYSTEM:?}
    command: serve all
    networks:
      - intranet
    # Порты наружу НЕ публикуем. Доступ только через APISIX.

  # (Опционально для dev) Демо-приложение Login/Consent
  hydra-login-consent:
    image: oryd/hydra-login-consent-node:v2.3.0
    depends_on:
      - hydra
    environment:
      HYDRA_ADMIN_URL: http://hydra:4445
      # Базовый URL этого приложения за APISIX
      BASE_URL: https://${OIDC_ISSUER_DOMAIN:?}
      NODE_ENV: production
    networks:
      - intranet

networks:
  intranet:
    external: true

volumes:
  hydra_pg_data:
```

- Настройте в Coolify переменные: `HYDRA_DB_USER`, `HYDRA_DB_PASSWORD`, `HYDRA_DB_NAME`, `HYDRA_SECRETS_SYSTEM`, `OIDC_ISSUER_DOMAIN` (например, auth.app-server.ru).
- Внешняя публикация Hydra идёт только через APISIX (см. ниже маршрут).

---

### Файл 2: docker-compose.identity.yml (Управление пользователями — ORY Kratos)

```yaml
version: '3.8'

services:
  kratos-pg:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: ${KRATOS_DB_USER:-kratos}
      POSTGRES_PASSWORD: ${KRATOS_DB_PASSWORD:?}
      POSTGRES_DB: ${KRATOS_DB_NAME:-kratos}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${KRATOS_DB_USER:-kratos}"]
      interval: 10s
      timeout: 30s
      retries: 5
    volumes:
      - kratos_pg_data:/var/lib/postgresql/data
    networks:
      - intranet

  kratos-migrate:
    image: oryd/kratos:v1.3.1
    depends_on:
      - kratos-pg
    environment:
      DSN: postgres://${KRATOS_DB_USER:-kratos}:${KRATOS_DB_PASSWORD:?}@kratos-pg:5432/${KRATOS_DB_NAME:-kratos}?sslmode=disable&max_conns=20&max_idle_conns=4
    command: -c /etc/config/kratos/kratos.yml migrate sql -e --yes
    volumes:
      - type: bind
        source: ./docker/kratos/configs
        target: /etc/config/kratos
    restart: on-failure
    networks:
      - intranet

  kratos:
    image: oryd/kratos:v1.3.1
    depends_on:
      - kratos-migrate
    environment:
      DSN: postgres://${KRATOS_DB_USER:-kratos}:${KRATOS_DB_PASSWORD:?}@kratos-pg:5432/${KRATOS_DB_NAME:-kratos}?sslmode=disable&max_conns=20&max_idle_conns=4
      LOG_LEVEL: info
    command: serve -c /etc/config/kratos/kratos.yml --dev --watch-courier
    volumes:
      - type: bind
        source: ./docker/kratos/configs
        target: /etc/config/kratos
    networks:
      - intranet

  # (Опционально) Пример UI для self-service
  kratos-selfservice-ui:
    image: oryd/kratos-selfservice-ui-node:v1.3.1
    environment:
      KRATOS_PUBLIC_URL: http://kratos:4433/
      KRATOS_BROWSER_URL: https://${IDENTITY_DOMAIN:?}/
      COOKIE_SECRET: ${KRATOS_COOKIE_SECRET:?}
      CSRF_COOKIE_NAME: ory_csrf_ui
      CSRF_COOKIE_SECRET: ${KRATOS_CSRF_SECRET:?}
    networks:
      - intranet
    restart: on-failure

networks:
  intranet:
    external: true

volumes:
  kratos_pg_data:
```

- Потребуются конфиги в `./docker/kratos/configs/kratos.yml` (см. пример ниже) и секреты (через Coolify).
- Наружу публикует APISIX; Kratos `public` (4433) и `admin` (4434) не мапим на хост.

Минимальный пример `kratos.yml` (вставьте в `./docker/kratos/configs/kratos.yml`):
```yaml
version: v0.12.0

dsn: ${DSN}

serve:
  public:
    base_url: https://${IDENTITY_DOMAIN}
    cors:
      enabled: true
  admin:
    base_url: http://kratos:4434

selfservice:
  default_browser_return_url: https://${IDENTITY_DOMAIN}/
  flows:
    login:
      ui_url: https://${IDENTITY_DOMAIN}/
    registration:
      ui_url: https://${IDENTITY_DOMAIN}/
    settings:
      ui_url: https://${IDENTITY_DOMAIN}/
    recovery:
      enabled: true
      ui_url: https://${IDENTITY_DOMAIN}/
    verification:
      enabled: true
      ui_url: https://${IDENTITY_DOMAIN}/

log:
  level: info

courier:
  smtp:
    connection_uri: noop:// # без mailslurper; замените на SMTP при необходимости
```

---

### Как связать через APISIX (один внешний шлюз)

- APISIX публикуется в интернет через Traefik (Traefik-лейблы только на APISIX).
- APISIX роутит path’ы на внутренние апстримы `hydra:4444` и `kratos:4433`.

Фрагмент `docker/apisix/config.yaml` (идея маршрутов):
```yaml
routes:
  - name: hydra-public
    uri: /oauth2/*
    upstream:
      type: roundrobin
      nodes:
        "hydra:4444": 1

  - name: hydra-well-known
    uri: /.well-known/*
    upstream:
      type: roundrobin
      nodes:
        "hydra:4444": 1

  - name: kratos-public
    uri: /self-service/*
    upstream:
      type: roundrobin
      nodes:
        "kratos:4433": 1

  - name: kratos-sessions
    uri: /sessions/*
    upstream:
      type: roundrobin
      nodes:
        "kratos:4433": 1

  - name: kratos-identities
    uri: /identities/*
    upstream:
      type: roundrobin
      nodes:
        "kratos:4433": 1
```

Traefik-лейблы для APISIX (пример на домен `auth.app-server.ru`):
- В compose APISIX уберите host-порты и добавьте:
```
labels:
  - traefik.enable=true
  - traefik.http.routers.apisix.entryPoints=websecure
  - traefik.http.routers.apisix.rule=Host(`auth.app-server.ru`)
  - traefik.http.routers.apisix.tls=true
  - traefik.http.services.apisix.loadbalancer.server.port=9080
```

---

Куда указывать URL’ы:
- Issuer (Hydra): `https://auth.app-server.ru` (через APISIX). Пропишите в `URLS_SELF_ISSUER`.
- Для прод-связки Hydra↔Kratos лучше указать `URLS_LOGIN`/`URLS_CONSENT` на страницы Kratos Self-Service UI (или ваш кастомный UI), например:
  - `URLS_LOGIN=https://auth.app-server.ru/self-service/login/browser`
  - `URLS_CONSENT=https://auth.app-server.ru/consent` (реализуется в UI/бэке и общается с Hydra Admin API)

Так вы получите:
- Изолированный OIDC-провайдер (Hydra) — “простая” выдача токенов/метаданных,
- Отдельную систему управления пользователями (Kratos),
- Один внешний вход — только через APISIX/Traefik,
- Чистое разделение ответственности и удобство масштабирования.