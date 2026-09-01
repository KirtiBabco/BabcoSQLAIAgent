<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Admin.aspx.cs" Inherits="SQL_AI_Agent.Admin" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Cost & Admin - Babco SQL AI Agent</title>
    <link rel="stylesheet" href="SqlAgent0106.css?v=20260901.1" />
</head>
<body>
<form id="form1" runat="server">
<div class="prototypeRibbon">PROTOTYPE</div>
<header class="finalHeader">
    <div class="finalBrand"><div class="brandMark">B</div><div><span class="eyebrow">BABCO LABS · SQL AI AGENT</span><h1>AI Usage & Cost</h1><p>APP-BAB-0106 style administration workspace</p></div></div>
    <div class="finalHeaderState"><span class="statePill"><i></i> Admin</span><span class="statePill"><%= Server.HtmlEncode(UserEmail) %></span><a class="headerBtn" href="Default.aspx">Back to Agent</a><a class="headerBtn" href="/.auth/logout?post_logout_redirect_uri=%2FLogin.aspx">Logout</a></div>
</header>
<nav class="finalNav"><a class="finalNavItem" href="Default.aspx"><span>✦</span> Today</a><a class="finalNavItem" href="Default.aspx#agent"><span>⌁</span> SQL Agent</a><a class="finalNavItem active" href="Admin.aspx"><span>◫</span> Cost</a><a class="finalNavItem" href="Help.aspx"><span>?</span> Help</a><a class="finalNavItem" href="Standard.aspx"><span>▣</span> Standard</a><a class="finalNavItem" href="Diagnostics.aspx"><span>⚙</span> Diagnostics</a></nav>
<main class="page">
    <section class="hero"><div><h2>Admin Console</h2><p class="muted">Runtime configuration and estimated OpenAI rate-card visibility. No Email or Teams functions are included.</p></div><span class="tag">Admin only</span></section>
    <div class="infoGrid">
        <section class="card">
            <div class="panelHead"><div><h3>Admin Access</h3><p class="muted">Current application session.</p></div></div>
            <div class="infoRow"><span class="k">User</span><span class="v"><%= Server.HtmlEncode(UserName) %></span></div>
            <div class="infoRow"><span class="k">Email</span><span class="v"><%= Server.HtmlEncode(UserEmail) %></span></div>
            <div class="infoRow"><span class="k">Role</span><span class="v">Admin</span></div>
            <div class="infoRow"><span class="k">Authentication</span><span class="v"><%= Server.HtmlEncode(AuthProvider) %></span></div>
        </section>
        <section class="card">
            <div class="panelHead"><div><h3>Runtime Status</h3><p class="muted">Server-side AI and SQL configuration.</p></div></div>
            <div class="infoRow"><span class="k">OpenAI Model</span><span class="v"><%= Server.HtmlEncode(OpenAIModel) %></span></div>
            <div class="infoRow"><span class="k">OpenAI Key</span><span class="v"><%= Server.HtmlEncode(OpenAIKeyStatus) %></span></div>
            <div class="infoRow"><span class="k">Babco SQL Setting</span><span class="v"><%= Server.HtmlEncode(SqlSettingStatus) %></span></div>
            <div class="infoRow"><span class="k">SQL Mode</span><span class="v">Read only</span></div>
        </section>
        <section class="card" style="grid-column:1/-1">
            <div class="panelHead"><div><h3>Configured OpenAI Rate Card</h3><p class="muted">Estimated rates used by the current application configuration.</p></div><span class="tag">Cost</span></div>
            <div class="infoRow"><span class="k">Input price</span><span class="v"><%= Server.HtmlEncode(InputPrice) %></span></div>
            <div class="infoRow"><span class="k">Cached input price</span><span class="v"><%= Server.HtmlEncode(CachedInputPrice) %></span></div>
            <div class="infoRow"><span class="k">Output price</span><span class="v"><%= Server.HtmlEncode(OutputPrice) %></span></div>
            <p class="muted" style="margin:14px 0 0;line-height:1.6">This page shows the existing SQL Agent costing/admin configuration. It does not add Outlook, Email, Teams, or Microsoft Graph functionality.</p>
        </section>
    </div>
    <div class="footer">Internal Use Only · Babco Labs Prototype · SQL AI Agent</div>
</main>
</form>
</body>
</html>
