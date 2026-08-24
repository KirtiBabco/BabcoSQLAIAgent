<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Admin.aspx.cs" Inherits="SQL_AI_Agent.Admin" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Costing / Admin - SQL AI Agent</title>
    <style>
        *{box-sizing:border-box}body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:#f4f7fb;color:#1f2937}.top{background:linear-gradient(135deg,#172554,#2563eb);color:#fff;padding:18px 28px}.topin,.wrap{max-width:1180px;margin:auto}.topin{display:flex;align-items:center;justify-content:space-between;gap:14px}.brand{font-size:22px;font-weight:700}.actions{display:flex;align-items:center;gap:9px;flex-wrap:wrap}.badge,.btn{border-radius:18px;padding:8px 12px;font-size:12px;text-decoration:none}.badge{background:#dcfce7;color:#166534;font-weight:700}.btn{background:rgba(255,255,255,.15);border:1px solid rgba(255,255,255,.28);color:#fff}.wrap{padding:26px 18px}.hero{display:flex;justify-content:space-between;gap:18px;align-items:flex-start;margin-bottom:18px}.hero h1{margin:0 0 5px;font-size:26px}.muted{color:#64748b;margin:0}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.card{background:#fff;border-radius:14px;padding:20px;box-shadow:0 5px 25px rgba(15,23,42,.08)}.card h2{margin:0 0 15px;font-size:18px}.row{display:flex;justify-content:space-between;gap:18px;padding:10px 0;border-bottom:1px solid #eef2f7}.row:last-child{border-bottom:0}.k{color:#64748b}.v{font-weight:600;text-align:right}.good{color:#047857}.notice{margin-top:16px;padding:14px;border-radius:12px;background:#eff6ff;border:1px solid #bfdbfe;color:#1e40af}.full{grid-column:1/-1}@media(max-width:760px){.topin,.hero{flex-direction:column}.grid{grid-template-columns:1fr}.full{grid-column:auto}.v{text-align:left}.row{flex-direction:column;gap:4px}}
    </style>
</head>
<body>
<form id="form1" runat="server">
<div class="top"><div class="topin">
    <div class="brand">SQL AI Agent - Costing / Admin</div>
    <div class="actions">
        <span class="badge">Admin</span>
        <a class="btn" href="Default.aspx">Back to Agent</a>
        <a class="btn" href="/.auth/logout?post_logout_redirect_uri=%2FLogin.aspx">Logout</a>
    </div>
</div></div>
<div class="wrap">
    <div class="hero">
        <div><h1>Admin Console</h1><p class="muted">Visible only to an authenticated Admin session.</p></div>
    </div>
    <div class="grid">
        <div class="card">
            <h2>Admin Access</h2>
            <div class="row"><span class="k">User</span><span class="v"><%= Server.HtmlEncode(UserName) %></span></div>
            <div class="row"><span class="k">Email</span><span class="v"><%= Server.HtmlEncode(UserEmail) %></span></div>
            <div class="row"><span class="k">Role</span><span class="v good">Admin</span></div>
            <div class="row"><span class="k">Authentication</span><span class="v"><%= Server.HtmlEncode(AuthProvider) %></span></div>
        </div>
        <div class="card">
            <h2>Runtime Status</h2>
            <div class="row"><span class="k">OpenAI Model</span><span class="v"><%= Server.HtmlEncode(OpenAIModel) %></span></div>
            <div class="row"><span class="k">OpenAI Key</span><span class="v"><%= Server.HtmlEncode(OpenAIKeyStatus) %></span></div>
            <div class="row"><span class="k">Babco SQL Setting</span><span class="v"><%= Server.HtmlEncode(SqlSettingStatus) %></span></div>
            <div class="row"><span class="k">SQL Mode</span><span class="v">Read only</span></div>
        </div>
        <div class="card full">
            <h2>Costing</h2>
            <div class="row"><span class="k">Input price</span><span class="v"><%= Server.HtmlEncode(InputPrice) %></span></div>
            <div class="row"><span class="k">Cached input price</span><span class="v"><%= Server.HtmlEncode(CachedInputPrice) %></span></div>
            <div class="row"><span class="k">Output price</span><span class="v"><%= Server.HtmlEncode(OutputPrice) %></span></div>
            <div class="notice">The current source does not persist request-level token usage/cost history. This page intentionally shows only the existing configured costing values and does not change SQL, Entra, or OpenAI runtime settings.</div>
        </div>
    </div>
</div>
</form>
</body>
</html>
