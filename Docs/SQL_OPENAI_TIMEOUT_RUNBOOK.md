# SQL AI Agent - SQL/OpenAI Timeout Runbook

## Purpose

This runbook prevents a repeat of the live error:

`500 - The request timed out.`

A browser-side 500/timeout is only a symptom. Never label it SQL or OpenAI until Auth, SQL and OpenAI are tested independently from the same Azure App Service worker that runs the Web Forms application.

## Confirmed findings from this incident

1. Microsoft Entra / Azure App Service Easy Auth was healthy.
2. `OPENAI_API_KEY_DEVELOPMENT` was present and an independent live OpenAI `/v1/responses` test returned HTTP 200.
3. `BAP_SUPPORT_CONNECTION_STRING` was present.
4. Safe key-name inspection showed a real SQL-style value with keys such as:
   - `Data Source`
   - `initial catalog`
   - `uid`
   - `password`
   - timeout field
5. Several misleading errors came from diagnostics/config formatting rather than the real database:
   - `ConnectTimeout=` is not accepted by .NET Framework `System.Data.SqlClient`; use `Connect Timeout=`.
   - `Timeout=` is normalized to `Connect Timeout=`.
   - A copied outer `ConnectionString=` wrapper must be removed before parsing.
   - PowerShell assignment through the wrong builder pattern produced a false `Keyword not supported: 'ConnectionString'`; validation must use the `SqlConnectionStringBuilder(string)` constructor.
6. Kudu/SCM can observe a stale environment snapshot after App Service configuration changes. Kudu is useful for deployment diagnostics, but it is not the final authority for application runtime SQL health.
7. Rapid overlapping GitHub deployments can collide during ZIP deploy/restart. Production deployment is therefore serialized with a GitHub Actions concurrency lock.

## Server-side settings

SQL:

`BAP_SUPPORT_CONNECTION_STRING`

OpenAI:

`OPENAI_API_KEY_DEVELOPMENT`

Optional OpenAI model override:

`OPENAI_MODEL`

Never put the SQL connection value or OpenAI API key in source code, GitHub commits, logs, screenshots, documentation, client-side JavaScript or HTML.

## Permanent SQL connection normalization rules

Before `SqlConnection` sees the string, `AppConfig.SqlConnectionString` must normalize compatible shared/copied formats:

- Strip a leading `BAP_SUPPORT_CONNECTION_STRING=` assignment wrapper if accidentally copied.
- Strip a leading `ConnectionString=` wrapper if accidentally copied.
- Remove matching outer single/double quotes.
- `ConnectTimeout=` -> `Connect Timeout=`.
- `ConnectionTimeout=` -> `Connection Timeout=`.
- `Timeout=` -> `Connect Timeout=`.

The deployment workflow may canonicalize the Azure value to the plain SQL connection-string form, but it must never print the value.

## Bounded timeout rules

Do not solve configuration/network failures by simply increasing timeouts.

Production rules:

- SQL connection timeout: **10 seconds**.
- SQL command timeout: `CommandTimeoutSeconds`, default **30 seconds**.
- OpenAI HTTP request/read-write timeout: **30 seconds**.
- ASP.NET execution timeout may be longer for the full agent request, but each backend dependency must have its own shorter bounded timeout.

This ensures the user receives a real SQL/OpenAI error instead of waiting until Azure/IIS emits a generic timeout page.

## Actual-worker backend health check

The final backend authority is the real ASP.NET App Service worker, not a separate Kudu process.

Deployment temporarily creates a random server-side setting:

`BAP_HEALTH_TOKEN`

The workflow calls `HealthCheck.aspx` with the matching `X-Babco-Health-Token` header. Without the token the page returns 404.

The health page runs inside the same Web Forms application process and performs:

1. SQL connection using `AppConfig.SqlConnectionString`.
2. Read-only SQL smoke query:
   `SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES`
3. OpenAI request using the application's `OpenAIClient`.
4. Only safe status output is returned; secrets are never returned.

After the check, the workflow deletes `BAP_HEALTH_TOKEN`. The health endpoint is therefore unusable without a newly generated deployment token.

Expected safe markers:

- `HEALTH_PAGE_OK=true`
- `SQL_OK=true`
- `SQL_TABLE_COUNT=<number>`
- `OPENAI_OK=true`

## Deployment concurrency rule

`.github/workflows/azure-app-service.yml` must contain a production concurrency lock:

- Group: `babco-sqlagent-production`
- `cancel-in-progress: true`

Only the latest deployment should modify/restart the production App Service. Never run multiple ZIP deployments to the same App Service concurrently.

## Mandatory production deployment gate

The production workflow uses GitHub OIDC and `scripts/deploy-and-verify.ps1`.

A deployment is complete only when all of the following are true:

- `PACKAGE=success`
- Full source package reconstruction succeeds.
- Production overrides are applied.
- No local/temporary admin login bypass exists.
- Easy Auth code is present.
- `SQL_SETTING_PRESENT=true`
- `OPENAI_SETTING_PRESENT=true`
- `SQL_PARSE_OK=true`
- `DEPLOY=success`
- Actual ASP.NET worker health page executes.
- `SQL_OK=true`
- `SQL_TABLE_COUNT=<number>`
- `OPENAI_OK=true`
- `BACKEND=success`
- Login returns HTTP 200.
- `/.auth/login/aad` redirects to Microsoft (3xx).
- Unauthenticated `Default.aspx` redirects (3xx).
- `VERIFY=success`
- `VERIFIED_LIVE=true`

Safe deployment results are published to the `deployment-status` branch. Do not declare the site healthy from ZIP deployment or Login.aspx alone.

## SQL failure classification after parsing succeeds

If `SQL_PARSE_OK=true` but `SQL_OK=false`, the remaining error is a genuine runtime category. Fix it by the exact exception, not by guessing:

1. **Connection timeout / server not found**
   - Verify SQL hostname/instance and TCP port.
   - Verify Azure App Service outbound connectivity to the SQL server.
   - Verify SQL firewall/network rules permit the App Service path.
   - If the database is on a private/on-prem network, provide VNet/Hybrid Connection/VPN/private networking as appropriate.

2. **Login failed**
   - Verify SQL username/password in the server-side setting.
   - Verify SQL authentication mode and login state.
   - Never expose the password in chat or logs.

3. **Cannot open database / initial catalog error**
   - Verify database name.
   - Verify the login has access to that database.

4. **Certificate/encryption error**
   - Use the SQL server's supported encryption/certificate settings.
   - Do not disable security globally merely to hide a certificate error.

5. **Permission denied after connection succeeds**
   - The SQL identity should be read-only and have only the permissions required for SELECT/schema metadata.

## OpenAI failure classification

The OpenAI key was independently proven usable during this incident. If OpenAI later fails, classify the HTTP result:

- 400: request/model parameters.
- 401/403: API key, project or access.
- 404: model/endpoint issue.
- 429: quota/rate limit.
- Network timeout: outbound connectivity or transient network issue.

Never expose the key or Authorization header.

## Security rules

- SQL stays read-only at both application guardrail and database-account permission levels.
- No SQL/OpenAI secret values in source or client-side output.
- Health token is random, temporary, server-side, and removed after deployment health verification.
- Health endpoint returns 404 without the valid temporary token.
- Local/temporary authentication bypass is not allowed in production.
- Authentication remains Microsoft Entra through Azure App Service Easy Auth.

## Root-cause lesson

The correct troubleshooting order is:

**Entra -> Settings present -> Connection-string parse -> Deploy -> Actual ASP.NET worker SQL -> Actual ASP.NET worker OpenAI -> Live page verification**

Do not use a generic browser 500, a static source check, or a separate Kudu environment alone as proof of application health. The final decision must come from the actual deployed worker with bounded backend timeouts and one serialized production deployment at a time.
