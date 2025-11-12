# Быстрый старт Zitadel на Coolify

## ⚡ Минимальная подготовка (5 минут)

### 1. Проверьте наличие файлов:

```bash
ls -la
docker-compose.yml
DEPLOYMENT.md
QUICKSTART.md
```

### 2. Создайте `.env` файл в корне проекта:

```bash
cat > .env << EOF
# PostgreSQL Configuration
POSTGRES_DB=zitadel
POSTGRES_USER=zitadel
POSTGRES_PASSWORD=MySecurePass2024!

# Zitadel Admin Configuration
ADMIN_USERNAME=admin@example.com
ADMIN_PASSWORD=AdminPass2024!

# Organization Configuration
ORG_NAME=MyOrganization

# External Configuration
ZITADEL_EXTERNALHOST=localhost:8080
ZITADEL_EXTERNALSECURE=false

# Logging
ZITADEL_LOGLEVEL=info
EOF
```

### 3. Запустите сервис:

```bash
docker-compose up -d
```

### 4. Проверьте статус:

```bash
docker-compose ps
docker-compose logs -f zitadel
```

### 5. Откройте в браузере:

```
http://localhost:8080
```

Используйте учетные данные:
- **Email**: admin@example.com
- **Пароль**: AdminPass2024!

---

## 🚀 Production развертывание на Coolify

### Шаг 1: Подготовьте сервер

```bash
# SSH на ваш сервер
ssh user@your-server.com

# Создайте директорию проекта
mkdir -p /opt/zitadel
cd /opt/zitadel

# Клонируйте/скопируйте файлы
# git clone <repo-url> . или скопируйте файлы
```

### Шаг 2: Создайте конфигурацию

```bash
# Скопируйте production конфиг
cp docker-compose.prod.yml docker-compose.yml
cp nginx.conf.example nginx.conf

# Отредактируйте .env для production
cat > .env << EOF
POSTGRES_DB=zitadel
POSTGRES_USER=zitadel
POSTGRES_PASSWORD=your_very_secure_password_here

ADMIN_USERNAME=admin@yourdomain.com
ADMIN_PASSWORD=your_admin_password_here

ORG_NAME=YourCompany

ZITADEL_EXTERNALHOST=zitadel.yourdomain.com
ZITADEL_EXTERNALSECURE=true

ZITADEL_LOGLEVEL=warn
EOF
```

### Шаг 3: Создайте SSL сертификаты

```bash
# Создайте директорию для сертификатов
mkdir -p certs

# Используйте Let's Encrypt (рекомендуется)
sudo certbot certonly --standalone -d zitadel.yourdomain.com

# Или скопируйте существующие сертификаты
cp /path/to/cert.pem certs/
cp /path/to/key.pem certs/
```

### Шаг 4: В Coolify

1. **Добавьте новый Service**:
   - Service Type: Docker Compose
   - Select Service: Create New Service
   - Name: Zitadel

2. **Загрузите конфигурацию**:
   - Выберите `docker-compose.prod.yml`
   - Или скопируйте содержимое вручную

3. **Установите переменные окружения**:
   - Скопируйте переменные из `.env`
   - Убедитесь, что пароли сильные

4. **Настройте Volume**:
   - `postgres_data`: `/var/lib/postgresql/data`
   - `zitadel_data`: `/zitadel`

5. **Нажмите "Deploy"**

### Шаг 5: Запустите и проверьте

```bash
# Просмотр логов
docker-compose logs -f

# Проверка статуса
docker-compose ps

# Проверка здоровья
docker-compose exec zitadel wget --spider http://localhost:8080/debug/livez
```

---

## 🔧 Типичные операции

### Просмотр логов

```bash
# Все логи
docker-compose logs

# Только Zitadel
docker-compose logs zitadel

# Только PostgreSQL
docker-compose logs postgres

# Последние 50 строк в реальном времени
docker-compose logs -f --tail=50
```

### Резервное копирование

```bash
# Полное резервное копирование БД
docker-compose exec postgres pg_dump -U zitadel zitadel | gzip > backup-$(date +%Y%m%d).sql.gz

# Список резервных копий
ls -lh backup-*.sql.gz
```

### Восстановление из резервной копии

```bash
# Остановить Zitadel
docker-compose down

# Удалить старую БД
docker volume rm zitadel_postgres_data

# Перезапустить только PostgreSQL
docker-compose up -d postgres

# Ждать 10 секунд инициализации
sleep 10

# Восстановить БД
gunzip < backup-20240101.sql.gz | docker-compose exec -T postgres psql -U zitadel zitadel

# Перезапустить все
docker-compose up -d
```

### Обновление Zitadel

```bash
# Скачайте новый образ
docker-compose pull

# Перезапустите контейнер
docker-compose up -d

# Проверьте логи
docker-compose logs zitadel
```

### Переменение пароля админа (если забыли)

```bash
# Остановить контейнеры
docker-compose down

# Удалить volume с БД (ВНИМАНИЕ: все данные будут удалены!)
docker volume rm zitadel_postgres_data
docker volume rm zitadel_zitadel_data

# Измените пароль в .env
# ADMIN_PASSWORD=new_password_here

# Перезапустите
docker-compose up -d
```

### Просмотр размера данных

```bash
# Размер БД
docker-compose exec postgres du -sh /var/lib/postgresql/data

# Размер Zitadel данных
docker-compose exec zitadel du -sh /zitadel
```

---

## ✅ Проверочный список перед Production

- [ ] Установлены сильные пароли (минимум 16 символов)
- [ ] SSL сертификаты установлены и действительны
- [ ] `.env` файл защищен (chmod 600)
- [ ] Резервные копии БД настроены на автоматическое выполнение
- [ ] SMTP сконфигурирован для отправки писем
- [ ] Firewall правила настроены (только 80/443 открыты)
- [ ] Логирование настроено на сохранение на диск
- [ ] DNS записи правильно указывают на сервер

---

## 📊 Мониторинг

### Основные метрики

```bash
# Использование ресурсов
docker stats

# Состояние контейнеров
docker-compose ps --format "table {{.Service}}\t{{.Status}}"

# Детальная информация
docker-compose exec postgres psql -U zitadel -d zitadel -c "SELECT version();"
```

---

## 🆘 Troubleshooting

### "Connection refused"

```bash
# Проверьте, запущены ли контейнеры
docker-compose ps

# Перезагрузите контейнеры
docker-compose restart

# Проверьте firewall
sudo ufw status
```

### "Database is being used"

```bash
# Перезагрузите PostgreSQL
docker-compose restart postgres

# Или очистите соединения
docker-compose exec postgres psql -U zitadel -d zitadel -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='zitadel' AND pid <> pg_backend_pid();"
```

### "Out of disk space"

```bash
# Проверьте использование
docker system df

# Очистите неиспользуемые образы
docker system prune -a

# Очистите логи (осторожно!)
docker-compose logs --tail 0 > /dev/null && docker logs $(docker ps -aq) --tail 0
```

---

## 📚 Дополнительные ресурсы

- [Zitadel Docs](https://zitadel.com/docs)
- [Docker Compose Docs](https://docs.docker.com/compose/)
- [Coolify Documentation](https://coolify.io/docs)
- [OIDC Standard](https://openid.net/connect/)

---

**Вопросы?** Проверьте полную документацию в `DEPLOYMENT.md`

