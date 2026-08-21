<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Login.aspx.cs" Inherits="SQL_AI_Agent.Login" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Login - SQL AI Agent</title>
    <style>
        *{box-sizing:border-box}body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:linear-gradient(145deg,#eef2ff,#f8fafc 48%,#ecfeff);color:#172033;min-height:100vh}
        .shell{min-height:100vh;display:grid;grid-template-columns:1.05fr .95fr}.brand{padding:64px;display:flex;flex-direction:column;justify-content:center;background:linear-gradient(145deg,#172554,#1d4ed8);color:#fff;position:relative;overflow:hidden}
        .brand:after{content:"";position:absolute;width:380px;height:380px;border-radius:50%;background:rgba(255,255,255,.08);right:-140px;bottom:-130px}.mark{font-size:14px;font-weight:700;letter-spacing:.16em;text-transform:uppercase;opacity:.78}.brand h1{font-size:48px;line-height:1.05;margin:18px 0 18px;max-width:650px}.brand p{font-size:18px;line-height:1.6;opacity:.86;max-width:600px}.points{display:grid;gap:12px;margin-top:28px}.point{display:flex;gap:12px;align-items:center;font-size:14px}.dot{width:9px;height:9px;border-radius:50%;background:#67e8f9;box-shadow:0 0 0 5px rgba(103,232,249,.12)}
        .login{display:flex;align-items:center;justify-content:center;padding:40px}.card{width:min(470px,100%);background:#fff;padding:34px;border-radius:20px;box-shadow:0 20px 70px rgba(30,41,59,.16);border:1px solid #e2e8f0}.eyebrow{font-size:12px;color:#2563eb;font-weight:800;letter-spacing:.12em;text-transform:uppercase}.card h2{font-size:28px;margin:9px 0 8px}.muted{color:#64748b;line-height:1.55;margin:0 0 24px}.btn{width:100%;border:0;border-radius:11px;padding:13px 16px;font-size:15px;font-weight:700;cursor:pointer}.entra{background:#2563eb;color:#fff}.btn:disabled{opacity:.5;cursor:not-allowed}.msg{margin-top:16px;padding:12px;border-radius:10px;background:#fff7ed;border:1px solid #fed7aa;color:#9a3412;white-space:pre-wrap;font-size:13px}.status{margin-top:18px;padding:12px;border-radius:10px;background:#f8fafc;border:1px solid #e2e8f0;font-size:12px;color:#475569;line-height:1.6}.secure{display:flex;gap:8px;align-items:center;margin-top:18px;color:#64748b;font-size:12px}
        @media(max-width:880px){.shell{grid-template-columns:1fr}.brand{padding:38px 28px}.brand h1{font-size:34px}.login{padding:28px 18px}.card{padding:26px}}
    </style>
</head>
<body>
<form id="form1" runat="server">
<div class="shell">
    <section class="brand">
        <div class="mark">Babco AI</div>
        <h1>SQL AI Agent Control & Analytics</h1>
        <p>Secure access to natural-language SQL analysis, AI usage telemetry, token cost visibility and the Admin Agent Flow console.</p>
        <div class="points">
            <div class="point"><span class="dot"></span><span>Microsoft Entra ID sign-in</span></div>
            <div class="point"><span class="dot"></span><span>Read-only SQL execution guardrails</span></div>
            <div class="point"><span class="dot"></span><span>Per-request token and USD cost tracking</span></div>
        </div>
    </section>
    <section class="login">
        <div class="card">
            <div class="eyebrow">Secure Sign In</div>
            <h2>Welcome back</h2>
            <p class="muted">Use your organization Microsoft account. Admin access is controlled by the configured admin email list.</p>
            <asp:Button ID="btnEntra" runat="server" Text="Sign in with Microsoft Entra ID" CssClass="btn entra" OnClick="btnEntra_Click" />
            <asp:Label ID="lblMessage" runat="server" CssClass="msg" Visible="false"></asp:Label>
            <div class="status"><asp:Literal ID="litConfigStatus" runat="server"></asp:Literal></div>
            <div class="secure">&#128274; Authentication is handled by Azure App Service Easy Auth. API and SQL credentials remain server-side.</div>
        </div>
    </section>
</div>
</form>
</body>
</html>
