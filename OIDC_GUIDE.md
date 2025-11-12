# Руководство по использованию Zitadel OIDC

## 📋 Содержание

1. [Как работает OIDC](#как-работает-oidc)
2. [Создание приложения](#создание-приложения)
3. [Примеры интеграции](#примеры-интеграции)
4. [Troubleshooting](#troubleshooting)

---

## Как работает OIDC

OpenID Connect (OIDC) - это протокол аутентификации, позволяющий приложениям проверять личность пользователя на основе аутентификации, выполненной Zitadel.

**Основной поток:**

1. Пользователь нажимает "Вход через Zitadel"
2. Приложение перенаправляет на Zitadel
3. Пользователь вводит учетные данные
4. Zitadel возвращает токен ID и Access Token
5. Приложение проверяет токен и создает сессию

---

## Создание приложения

### Шаг 1: Вход в Zitadel

1. Откройте `http://localhost:8080`
2. Нажмите "Login"
3. Используйте учетные данные админа:
   - Email: `admin@example.com`
   - Password: `AdminPass2024!`

### Шаг 2: Создание приложения

1. Перейдите в **Projects** → **Create New Project**
2. Введите название проекта: `MyApp`
3. Нажмите **Create**

4. В созданном проекте нажмите **New Application**
5. Выберите **Web**
6. Нажмите **Create**

7. Заполните параметры:
   - **Name**: `MyApp Web`
   - **Redirect URLs**: 
     ```
     http://localhost:3000/callback
     https://yourdomain.com/callback
     ```
   - **Post Logout Redirect URLs**:
     ```
     http://localhost:3000
     https://yourdomain.com
     ```

### Шаг 3: Получение учетных данных

После создания приложения вы получите:

- **Client ID**: `123456789@myapp.zitadel.cloud` (или локальный ID)
- **Client Secret**: `YourSecretHere` (сохраните в безопасности!)

Скопируйте эти значения - они понадобятся для интеграции.

### Шаг 4: Создание пользователя (опционально)

1. Перейдите в **Users** → **New User**
2. Заполните данные:
   - Email: `user@example.com`
   - First Name: `John`
   - Last Name: `Doe`
3. Установите пароль
4. Нажмите **Create**

---

## Примеры интеграции

### Node.js / Express

```javascript
const express = require('express');
const { Issuer, generators } = require('openid-client');

const app = express();

let client;

// Инициализация OIDC клиента
Issuer.discover('http://localhost:8080')
  .then(issuer => {
    client = new issuer.Client({
      client_id: 'YOUR_CLIENT_ID',
      client_secret: 'YOUR_CLIENT_SECRET',
      redirect_uris: ['http://localhost:3000/callback'],
      response_types: ['code'],
    });
  });

// Маршрут для начала аутентификации
app.get('/login', (req, res) => {
  const code_verifier = generators.codeVerifier();
  const code_challenge = generators.codeChallenge(code_verifier);
  
  req.session.code_verifier = code_verifier;
  
  const authorization_url = client.authorizationUrl({
    scope: 'openid email profile',
    code_challenge,
    code_challenge_method: 'S256',
  });
  
  res.redirect(authorization_url);
});

// Callback маршрут
app.get('/callback', async (req, res) => {
  const params = client.callbackParams(req);
  const tokenSet = await client.callback(
    'http://localhost:3000/callback',
    params,
    { code_verifier: req.session.code_verifier }
  );
  
  // Получена информация о пользователе
  const userinfo = await client.userinfo(tokenSet.access_token);
  
  // Создайте сессию или JWT
  req.session.user = userinfo;
  
  res.redirect('/');
});

// Защищенный маршрут
app.get('/dashboard', (req, res) => {
  if (!req.session.user) {
    return res.redirect('/login');
  }
  res.send(`Welcome, ${req.session.user.email}`);
});

app.listen(3000, () => console.log('Server on http://localhost:3000'));
```

### React

```javascript
import React, { useEffect } from 'react';
import { useAuth0 } from '@auth0/auth0-react';

// Или используйте react-oidc-context
import { AuthProvider, useAuth } from 'oidc-react';

const AuthConfig = {
  authority: 'http://localhost:8080',
  client_id: 'YOUR_CLIENT_ID',
  redirect_uri: 'http://localhost:3000/callback',
  scopes: ['openid', 'profile', 'email'],
};

function LoginButton() {
  const { login } = useAuth();
  
  return <button onClick={() => login()}>Login with Zitadel</button>;
}

function LogoutButton() {
  const { logout } = useAuth();
  
  return <button onClick={() => logout()}>Logout</button>;
}

function Dashboard() {
  const { user, isLoading } = useAuth();
  
  if (isLoading) return <div>Loading...</div>;
  
  return (
    <div>
      {user ? (
        <>
          <h1>Welcome, {user.name}</h1>
          <p>Email: {user.email}</p>
          <LogoutButton />
        </>
      ) : (
        <LoginButton />
      )}
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider {...AuthConfig}>
      <Dashboard />
    </AuthProvider>
  );
}
```

### Python / Flask

```python
from flask import Flask, redirect, url_for, session, request
from authlib.integrations.flask_client import OAuth

app = Flask(__name__)
app.secret_key = 'your-secret-key'
oauth = OAuth(app)

zitadel = oauth.register(
    'zitadel',
    server_metadata_url='http://localhost:8080/.well-known/openid-configuration',
    client_id='YOUR_CLIENT_ID',
    client_secret='YOUR_CLIENT_SECRET',
    client_kwargs={
        'scope': 'openid email profile',
    }
)

@app.route('/login')
def login():
    redirect_uri = url_for('authorize', _external=True)
    return zitadel.authorize_redirect(redirect_uri)

@app.route('/authorize')
def authorize():
    token = zitadel.authorize_access_token()
    user = token.get('userinfo')
    
    session['user'] = user
    
    return redirect(url_for('dashboard'))

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))
    
    user = session['user']
    return f"Welcome, {user['email']}"

@app.route('/logout')
def logout():
    session.clear()
    return redirect(zitadel.server_metadata.get('end_session_endpoint') + 
                   f'?id_token_hint={session.get("id_token")}&' +
                   f'post_logout_redirect_uri={url_for("index", _external=True)}')

if __name__ == '__main__':
    app.run()
```

### Go

```go
package main

import (
	"context"
	"log"
	"net/http"

	"github.com/coreos/go-oidc"
	"golang.org/x/oauth2"
)

func main() {
	ctx := context.Background()
	
	// Инициализация OIDC провайдера
	provider, err := oidc.NewProvider(ctx, "http://localhost:8080")
	if err != nil {
		log.Fatal(err)
	}

	config := oauth2.Config{
		ClientID:     "YOUR_CLIENT_ID",
		ClientSecret: "YOUR_CLIENT_SECRET",
		RedirectURL:  "http://localhost:8080/callback",
		Scopes:       []string{oidc.ScopeOpenID, "email", "profile"},
		Endpoint:     provider.Endpoint(),
	}

	http.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		authURL := config.AuthCodeURL("state")
		http.Redirect(w, r, authURL, http.StatusFound)
	})

	http.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		token, err := config.Exchange(ctx, code)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Получение информации о пользователе
		userInfo, err := provider.UserInfo(ctx, oauth2.StaticTokenSource(token))
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("Welcome, " + userInfo.Email))
	})

	log.Println("Server starting on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

---

## Troubleshooting

### "Invalid redirect URI"

**Проблема**: При попытке авторизации получаете ошибку о неправильном redirect URI

**Решение**:
1. Проверьте, что Redirect URI в приложении совпадает с тем, на который перенаправляет клиент
2. Убедитесь, что используется правильный протокол (http/https)
3. Проверьте порт

Пример правильного URI:
```
http://localhost:3000/callback
https://yourdomain.com/callback
```

### "Client secret mismatch"

**Проблема**: При обмене кода на токен - ошибка несовпадения secret

**Решение**:
1. Скопируйте client secret заново из Zitadel
2. Убедитесь, что secret хранится в переменной окружения, а не в коде
3. Проверьте, что нет скрытых пробелов

### "Userinfo endpoint returned an error"

**Проблема**: Не удается получить информацию о пользователе

**Решение**:
1. Убедитесь, что access token действителен
2. Проверьте, что сервис Zitadel запущен
3. Проверьте логи Zitadel: `docker-compose logs zitadel`

### "CORS error"

**Проблема**: Запросы с фронтенда блокируются из-за CORS

**Решение**:
1. Проверьте конфигурацию CORS в Zitadel
2. Добавьте origin вашего приложения в `ZITADEL_CORS_ALLOWEDORIGINS`

Пример в `.env`:
```
ZITADEL_CORS_ALLOWEDORIGINS=http://localhost:3000,https://yourdomain.com
```

---

## Безопасность

### Рекомендации

1. **Никогда** не храните client secret на фронтенде
2. Используйте HTTPS в production
3. Регулярно ротируйте secrets
4. Используйте PKCE flow для мобильных и SPA приложений
5. Установите короткий TTL для токенов
6. Логируйте все попытки авторизации

### Проверка токена

```javascript
// Пример проверки токена в Node.js
const jwt = require('jsonwebtoken');

function verifyToken(token, publicKey) {
  try {
    return jwt.verify(token, publicKey, { algorithms: ['RS256'] });
  } catch (error) {
    return null;
  }
}
```

---

## Дополнительные ресурсы

- [Zitadel OIDC Documentation](https://zitadel.com/docs/category/apis/openid_connect)
- [OpenID Connect Specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [OIDC Debugger](https://oidcdebugger.com/)
- [oidc-client-ts Library](https://github.com/authts/oidc-client-ts)

---

## Практические примеры

### Multi-tenant приложение

```javascript
// Используйте organization ID для multi-tenancy
const authorizationUrl = client.authorizationUrl({
  scope: 'openid email profile',
  login_hint: 'user@tenant.com',
  acr_values: 'urn:zitadel:params:oauth:assertion:org_id:{orgId}',
});
```

### Обновление токена

```javascript
async function refreshToken(refreshToken) {
  const tokenSet = await client.refresh(refreshToken);
  return tokenSet.access_token;
}
```

### Проверка прав доступа (RBAC)

```javascript
async function hasRole(userinfo, requiredRole) {
  const userRoles = userinfo.roles || [];
  return userRoles.includes(requiredRole);
}
```

---

**Успешной интеграции!** 🚀

