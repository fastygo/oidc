I'll add missing building blocks for Zero Trust ABAC: mount Kratos config properly, add an OPA policy engine with a starter policy, and prepare Hydra to issue JWT access tokens. Then I'll update the compose files accordingly and create the policy file.

[5 tools called]

- I mounted the Kratos config properly and enabled a usable SMTP dev mailbox. Next I added an OPA policy engine and a starter ABAC policy, and configured Hydra to support JWT access tokens.

### What’s missing for a sovereign, Zero Trust, ABAC-driven SSO
- Identity flows (IdP): You have Ory Kratos, but it must be fully configured and mounted (config, secrets, identity schema, WebAuthn, recovery/verification). I fixed the config mounting and enabled an SMTP dev mailbox.
- OIDC/OAuth2 provider: You have Ory Hydra. To enable edge token verification without round-trips, issue JWT access tokens. I enabled the env toggle; keep opaque tokens for resource servers that prefer introspection.
- Policy decision point (PDP): Add an ABAC engine (OPA/Cedar/Casbin). I added OPA with a starter policy and a volume for policies.
- Policy enforcement point (PEP): Enforce OIDC and ABAC at the gateway. With APISIX, use `openid-connect` (bearer_only) plus `opa` plugin on protected routes.
- Consent/login and claims enrichment: The login/consent app should fetch user attributes from Kratos and inject them into Hydra tokens (custom claims). This is key to ABAC.
- Secrets, PKI, and mTLS: Store secrets securely (Docker secrets/Vault), run an internal CA (e.g., step-ca/Vault PKI), and use mTLS between gateway and upstreams (and for admin APIs).
- Observability and audit: Enable Prometheus metrics, tracing, and centralized logs (APISIX Prometheus/OTel plugin, Loki/ELK). Keep audit trails for authn/authz decisions.
- Client bootstrap and lifecycle: Automate Hydra client provisioning (admin API/CLI). Consider OPAL or GitOps for policy distribution/versioning.
- Hardening and controls: CORS, WAF/bot detection, rate limiting, IP allow/deny, device posture signals, session management constraints, token lifetimes, and rotation.

### Changes made to your compose files
- `docker-compose.identity.yml`
  - Mounted Kratos config and updated command to use it.
  - Switched Kratos courier to a dev SMTP mailbox (`maildev`).
  - Added `maildev` service.

```77:92:docker-compose.identity.yml
      # Mail (на проде замените на реальный SMTP URI)
      COURIER_SMTP_CONNECTION_URI: smtp://maildev:1025/?skip_ssl_verify=true
    command: serve -c /etc/config/kratos/kratos.yml --dev --watch-courier
    volumes:
      - type: bind
        source: ./docker/kratos/configs
        target: /etc/config/kratos
```

- `docker-compose.apisix.yml`
  - Added OPA PDP service with a bind-mounted policy folder.

```114:129:docker-compose.apisix.yml
  opa:
    image: openpolicyagent/opa:0.64.1
    command:
      - run
      - --server
      - --addr=0.0.0.0:8181
      - /policies
    volumes:
      - type: bind
        source: ./docker/opa/policies
        target: /policies
        read_only: true
    networks:
      - intranet
```

- `docker-compose.oidc-provider.yml`
  - Enabled JWT access tokens in Hydra (for edge verification).

```38:48:docker-compose.oidc-provider.yml
      SERVE_PUBLIC_PORT: "4444"
      SERVE_ADMIN_PORT: "4445"
      # Разрешить проверку токенов по JWKS (JWT access tokens)
      STRATEGIES_ACCESS_TOKEN: jwt
      # ВАЖНО: Укажите публичный Issuer (домен APISIX)
      URLS_SELF_ISSUER: https://${OIDC_ISSUER_DOMAIN:?}
```

- Added a starter ABAC policy file at `docker/opa/policies/authz.rego` (deny-by-default, allows `/.well-known/*`, example JWT-claim rule for `acr == "mfa"`, and a simple service header path). Tune to your attributes and resources.

### How to wire APISIX for OIDC + ABAC on a protected route
- Create an OAuth client in Hydra for APISIX (client credentials + auth code, scopes `openid profile email offline_access`). Then, on the APISIX route you want to protect:
  - Attach `openid-connect` in `bearer_only: true` mode
    - discovery: `https://${OIDC_ISSUER_DOMAIN}/.well-known/openid-configuration`
    - For Hydra with JWT access tokens, APISIX will validate using JWKS.
    - If you keep opaque tokens, set the introspection endpoint and client credentials.
  - Attach the `opa` plugin pointing to `http://opa:8181/v1/data/http/authz/allow`.
- Keep identity endpoints (Kratos/Hydra `/.well-known/*`, `/oauth2/*`, `self-service/*`) without auth to avoid breaking flows.

Example Admin API (adjust IDs/domains/secrets as needed):

```bash
# OIDC + ABAC protected route to an upstream app on apisix-admin
curl -X PUT "${APISIX_ADMIN}/apisix/admin/routes/app-protected" \
  -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"uri\": \"/app/*\",
    \"upstream\": { \"type\": \"roundrobin\", \"nodes\": { \"app:8080\": 1 } },
    \"plugins\": {
      \"openid-connect\": {
        \"discovery\": \"https://${OIDC_ISSUER_DOMAIN}/.well-known/openid-configuration\",
        \"bearer_only\": true,
        \"scope\": \"openid profile email offline_access\"
      },
      \"opa\": {
        \"host\": \"http://opa:8181\",
        \"policy\": \"http/authz/allow\"
      }
    }
  }"
```

### Recommended next steps
- Populate `docker/kratos/configs/kratos.yml` with secrets, identity schemas, and WebAuthn/MFA policies; migrate traits you want as ABAC attributes.
- Implement Login/Consent app logic to fetch Kratos identity and inject required custom claims into Hydra tokens (ID/access token session data).
- Bootstrap Hydra clients (APISIX, UI, APIs) via admin API or a one-off init job.
- Tighten edge controls: APISIX `cors`, `limit-req`, `ip-restriction`, `bot-detection`, WAF, mTLS to upstreams.
- Add secrets management (Docker secrets or Vault), PKI (step-ca/Vault), and observability (Prometheus/Grafana, logs).

All tasks are completed and checked off.

- Mounted Kratos config and enabled dev SMTP.
- Added OPA PDP with a starter ABAC policy at `docker/opa/policies/authz.rego`.
- Enabled Hydra JWT access tokens for gateway-side verification.
- Provided concrete APISIX route configuration example for OIDC + ABAC enforcement.