> gpt-5-high

- Я создал единый стек `docker-compose.ory.yml` с:
  - Hydra + Postgres
  - APISIX (+ etcd) и Traefik-лейблами на домен `${AUTH_DOMAIN}`
  - Демо UI для login/consent (чтобы сразу тестировать поток авторизации)

Как использовать в Coolify:
1) Создайте новый “Docker Compose” сервис и укажите `docker-compose.ory.yml`.
2) Введите переменные окружения:
   - AUTH_DOMAIN=auth.app-server.ru
   - HYDRA_DB_USER=hydra
   - HYDRA_DB_PASSWORD=strong-db-pass
   - HYDRA_DB_NAME=hydra
   - HYDRA_SECRETS_SYSTEM=long-secret-for-hydra
   - APISIX_ADMIN_KEY=any-strong-key
3) Деплой.
4) Проверка:
   - https://auth.app-server.ru/.well-known/openid-configuration → JSON от Hydra
   - https://auth.app-server.ru/login → демо-страница логина (из hydra-login-consent)
5) Создайте OIDC-клиент (через Exec в контейнере `hydra`):
   - Пример: `hydra clients create --endpoint http://hydra:4445 --id demo --secret demo-secret --grant-types authorization_code,refresh_token --response-types code --scope openid,offline --callbacks https://yourapp/callback`
6) Протестируйте авторизацию:
   - https://auth.app-server.ru/oauth2/auth?client_id=demo&response_type=code&scope=openid&redirect_uri=https://yourapp/callback

Если нужно, добавлю в этот же файл Kratos (управление пользователями) без SMTP — с отключёнными верификациями и маршрутизацией через APISIX.