# Full deployment source package

The 12 `partXX.b64` files reconstruct the complete modified source archive used for Azure deployment.

- SHA-256: `b02c69ab1b4ab431f823a2e3327faada3019f1a815470dd445e321128ca2559a`
- Authentication: Azure App Service Easy Auth / Microsoft Entra only.
- Local/temporary admin bypass: removed.
- SQL: reads only the server-side `BAP_SUPPORT_CONNECTION_STRING` environment setting; no SQL credential is stored in source.
- OpenAI: reads the server-side `OPENAI_API_KEY_DEVELOPMENT` setting.

The deployment workflow reconstructs this archive, verifies the SHA-256, deploys the nested `SQL_AI_Agent` WebForms site, and performs live authentication checks.
