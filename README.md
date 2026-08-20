# Babco SQL AI Agent

ASP.NET WebForms SQL AI Agent live application.

## Live

- Azure App Service: `babco-sqlagent-wf-2c606af4`
- Live URL: https://babco-sqlagent-wf-2c606af4.azurewebsites.net/
- Login URL: https://babco-sqlagent-wf-2c606af4.azurewebsites.net/Login.aspx
- Azure resource group: `rg-babco-rnd-sandbox`
- Existing Windows App Service plan: `plan-resolvedesk-kirti20260810`
- Database setting: `BAP_SUPPORT_CONNECTION_STRING`
- Database connection binding: configured server-side in Azure
- Admin allowlist: `kirti@babcofoods.com`, `ken@babcofoods.com`, `hemant@babcofoods.com`

## Deployment pattern

This repository follows the same deployment pattern as `KirtiBabco/BabcoUnloadCompare`: GitHub Actions, Azure OIDC, Windows App Service, direct ZIP deployment to `wwwroot`, restart, and HTTP health verification.

Secrets and connection strings are never stored in browser code or committed to this repository.
