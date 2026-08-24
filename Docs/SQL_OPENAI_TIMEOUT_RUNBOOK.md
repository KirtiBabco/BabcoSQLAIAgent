# SQL AI Agent - SQL/OpenAI Timeout Runbook

## Incident fixed

Observed UI error:

`500 - The request timed out.`

The browser error alone did not identify the failing layer. Live Azure diagnostics isolated the backend and found two SQL connection-string formatting problems in sequence:

1. `Keyword not supported: 'ConnectTimeout'.`
2. `Keyword not supported: 'ConnectionString'.`

`BAP_SUPPORT_CONNECTION_STRING` existed, but a shared/copied value can contain either of these incompatible forms:

- `ConnectTimeout=` instead of the .NET Framework `System.Data.SqlClient` form `Connect Timeout=`.
- An outer wrapper `ConnectionString=<actual SQL connection string>`, which `System.Data.SqlClient` incorrectly sees as a connection-string keyword unless the wrapper is removed first.

The OpenAI API was tested independently from the same Azure App Service runtime and must return HTTP 200 before a deployment is declared healthy.

Required server-side OpenAI setting:

`OPENAI_API_KEY_DEVELOPMENT`

Never put either secret value in source code, GitHub, logs, screenshots, or documentation.

## Permanent code rules

1. SQL must always come from the server-side environment variable `BAP_SUPPORT_CONNECTION_STRING`.
2. `AppConfig.SqlConnectionString` must normalize shared/copied connection-string formats before `SqlConnection` sees them:
   - Strip an outer leading `ConnectionString=` wrapper if present.
   - Remove matching outer quotes if present.
   - `ConnectTimeout=` -> `Connect Timeout=`.
   - `ConnectionTimeout=` -> `Connection Timeout=`.
3. The app must never contain an embedded SQL server, user name, password, or full connection string.
4. OpenAI must come from `OPENAI_API_KEY_DEVELOPMENT`, with legacy fallback to `OPENAI_API_KEY` only where explicitly supported.
5. Default API model is `gpt-5-mini`; `OPENAI_MODEL` can override it from Azure without a source change.
6. ASP.NET `executionTimeout` is 300 seconds so the Web Forms request is not killed while the Agent performs SQL plus OpenAI work.
7. SQL command timeout remains bounded (`CommandTimeoutSeconds`, default 30); deployment smoke tests use a 10-second SQL timeout.
8. No local-admin or temporary-auth bypass is allowed. Authentication remains Azure App Service Easy Auth / Microsoft Entra ID.

## Mandatory deployment health gate

The production workflow `.github/workflows/azure-app-service.yml` runs one deterministic script: `scripts/deploy-and-verify.ps1`.

A deployment is not green merely because the ZIP uploaded or Login.aspx returned 200. The same deployment job must complete all of these checks after the App Service restart:

- Full source package reconstructs successfully.
- Production overrides are applied.
- No local/temporary login bypass exists.
- `BAP_SUPPORT_CONNECTION_STRING` is present.
- `OPENAI_API_KEY_DEVELOPMENT` is present.
- SQL connects from the actual App Service/Kudu runtime.
- Read-only query `SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES` succeeds.
- OpenAI `/v1/responses` smoke test succeeds and returns HTTP 200.
- Login page returns HTTP 200.
- Easy Auth returns a Microsoft redirect.
- Unauthenticated `Default.aspx` redirects instead of opening directly.

Safe results are published to the `deployment-status` branch. The connection string and API key must never be published.

Required success markers include:

- `PACKAGE=success`
- `SETTINGS=success`
- `DEPLOY=success`
- `BACKEND=success`
- `SQL_OK=true`
- `SQL_TABLE_COUNT=<number>`
- `OPENAI_OK=True` or `OPENAI_OK=true`
- `OPENAI_HTTP=200`
- `VERIFY=success`
- `VERIFIED_LIVE=true`

## If SQL fails

Check in this order:

1. Confirm `BAP_SUPPORT_CONNECTION_STRING` exists in Azure App Service Environment Variables.
2. Never print the value. Test only safe properties/results.
3. Normalize the outer `ConnectionString=` wrapper and timeout aliases before constructing `SqlConnectionStringBuilder` or `SqlConnection`.
4. Run the read-only smoke query from the App Service runtime, not only from a developer PC.
5. If parsing succeeds but connection fails, classify the actual SQL exception: DNS/server name, firewall/network, authentication, database name, certificate/encryption, or timeout.
6. Do not increase timeouts to hide a parsing, authentication, or network configuration error.

## If OpenAI fails

Check in this order:

1. Confirm `OPENAI_API_KEY_DEVELOPMENT` exists in Azure App Service Environment Variables.
2. Restart/redeploy after environment-variable changes so the worker process receives the setting.
3. Verify `OPENAI_MODEL`; default is `gpt-5-mini` unless Azure overrides it.
4. Run a short `/v1/responses` smoke test from the same App Service runtime.
5. Distinguish HTTP 400 (request/model parameters), 401/403 (key/project/access), 429 (quota/rate limit), 404/model issues, and network timeout.
6. Never display or log the API key or Authorization header.

## Root-cause lesson

A generic browser-side `500 - request timed out` is not enough to label the issue as SQL or OpenAI. Always isolate Auth, SQL, and OpenAI from the same Azure App Service runtime. Connection-string text copied from portals or shared configuration must be treated as input that can contain wrappers/aliases and normalized before `System.Data.SqlClient` parses it. Future deployments must fail the health gate instead of reporting success when either SQL or OpenAI is unhealthy.
