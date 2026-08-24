# SQL AI Agent - SQL/OpenAI Timeout Runbook

## Incident fixed

Observed UI error:

`500 - The request timed out.`

The live Azure diagnostic isolated the backend layers and found the first concrete SQL configuration failure:

`Keyword not supported: 'ConnectTimeout'.`

`BAP_SUPPORT_CONNECTION_STRING` existed, but the value used `ConnectTimeout=`. The application uses .NET Framework `System.Data.SqlClient`, which expects `Connect Timeout=` or `Connection Timeout=`.

A second deployment prerequisite is the server-side OpenAI API key. The required Azure App Service setting is:

`OPENAI_API_KEY_DEVELOPMENT`

Never put either secret value in source code, GitHub, logs, screenshots, or documentation.

## Permanent code rules

1. SQL must always come from the server-side environment variable `BAP_SUPPORT_CONNECTION_STRING`.
2. `AppConfig.SqlConnectionString` normalizes these known aliases before `SqlConnection` sees them:
   - `ConnectTimeout=` -> `Connect Timeout=`
   - `ConnectionTimeout=` -> `Connection Timeout=`
3. The app must never contain an embedded SQL server, user name, or password.
4. OpenAI must come from `OPENAI_API_KEY_DEVELOPMENT` only, with optional fallback to `OPENAI_API_KEY` only where explicitly supported.
5. Default API model is a deployable API model (`gpt-5-mini`). `OPENAI_MODEL` can override it from Azure without a source change.
6. ASP.NET `executionTimeout` is 300 seconds so the Web Forms request is not killed while the Agent performs SQL plus API work.
7. SQL command timeout remains bounded (`CommandTimeoutSeconds`, default 30) and runtime smoke tests use 10 seconds.
8. No local-admin or temporary-auth bypass is allowed. Authentication remains Azure App Service Easy Auth / Microsoft Entra ID.

## Mandatory diagnostics before declaring the site healthy

The GitHub Actions `Runtime Diagnostics` workflow runs from inside the Azure App Service/Kudu environment and publishes only safe status values.

Required results:

- `SQL_SETTING_PRESENT=True`
- `SQL_OK=true`
- `SQL_TABLE_COUNT=<number>`
- `OPENAI_KEY_PRESENT=True`
- `OPENAI_OK=True`
- `OPENAI_HTTP=200`

The workflow must never print the SQL connection string or OpenAI key.

## If SQL fails

Check in this order:

1. `BAP_SUPPORT_CONNECTION_STRING` exists in Azure App Service Environment Variables.
2. Restart the App Service after environment-variable changes.
3. Normalize connection-string aliases before constructing `SqlConnectionStringBuilder` or `SqlConnection`.
4. Test from the App Service environment, not only from a developer PC, using a read-only query such as:
   `SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES`
5. If parsing succeeds but connection fails, inspect the SQL error category: DNS/server name, firewall/network, authentication, database name, certificate/encryption, or timeout.
6. Do not increase timeouts to hide a connection/configuration error.

## If OpenAI fails

Check in this order:

1. `OPENAI_API_KEY_DEVELOPMENT` exists in Azure App Service Environment Variables.
2. Restart the App Service after changing the key.
3. Verify the selected `OPENAI_MODEL`; default is `gpt-5-mini` unless `OPENAI_MODEL` overrides it.
4. Run a short API smoke test from the App Service environment with a 25-second timeout.
5. Distinguish HTTP 401/403 (key/project/access), 429 (quota/rate limit), 404/model errors, and network timeout.
6. Never display raw HTML/IIS timeout pages as the final diagnosis; isolate SQL and OpenAI separately first.

## Deployment acceptance checklist

A deployment is complete only when all are true:

- Source package reconstructs successfully.
- Production overrides are applied.
- Local admin bypass is absent.
- Entra Easy Auth redirects correctly.
- `BAP_SUPPORT_CONNECTION_STRING` is present.
- `OPENAI_API_KEY_DEVELOPMENT` is present.
- SQL runtime smoke test passes.
- OpenAI runtime smoke test passes.
- Login page returns HTTP 200.
- Unauthenticated protected page redirects to sign-in.

## Root-cause lesson

A generic browser-side `500 - request timed out` is not enough to label the issue as SQL or OpenAI. Always test Auth, SQL, and OpenAI independently from the same Azure App Service runtime. This prevents repeated trial-and-error changes and makes the next failure immediately attributable to the correct layer.
