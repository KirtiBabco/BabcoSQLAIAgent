# Babco SQL AI Agent

Production deployment repository for the Babco SQL AI Agent WebForms application.

## Current authentication
Microsoft Entra ID is handled by Azure App Service Easy Auth (`/.auth/login/aad`). The application has no local/temporary admin login bypass and does not require an Entra client secret in source.

## Server-side configuration
- `BAP_SUPPORT_CONNECTION_STRING` - global Babco SQL connection string (value never committed).
- `OPENAI_API_KEY_DEVELOPMENT` - OpenAI API key (value never committed).
- `AI_SQL_AGENT_ADMIN_EMAILS` - optional comma/semicolon-separated list controlling application Admin role after Entra sign-in.

## Deployment source
`source-package/part01.b64` through `part12.b64` form the full source archive. The deployment workflow verifies its SHA-256 before deploying to `babco-sqlagent-wf-2c606af4`.
