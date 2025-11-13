package http.authz

# Default deny
default allow = false

# Example ABAC starter policy.
# Adjust to your domain model. This policy demonstrates three common cases:
# 1) Allow public metadata endpoints (GET /.well-known/*)
# 2) Allow if a Bearer token claim indicates strong auth (acr == "mfa")
# 3) Allow internal service calls that identify themselves (e.g., via x-service header)

# Case 1: Public discovery endpoints
allow {
  input.request.method == "GET"
  startswith(input.request.path, "/.well-known/")
}

# Case 2: Claims-based ABAC using JWT "acr" claim (decoded without verification)
allow {
  some token
  token := input.request.headers["authorization"]
  startswith(lower(token), "bearer ")
  parts := split(token, " ")
  count(parts) == 2
  [_hdr, payload, _sig] := io.jwt.decode(parts[1])
  payload.acr == "mfa"
}

# Case 3: Internal service-to-service call (example)
allow {
  input.request.headers["x-service"] != ""
}



