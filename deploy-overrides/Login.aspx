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
        .login{display:flex;align-items:center;justify-content:center;padding:40px}.card{width:min(470px,100%);background:#fff;padding:34px;border-radius:20px;box-shadow:0 20px 70px rgba(30,41,59,.16);border:1px solid #e2e8f0}.eyebrow{font-size:12px;color:#b45309;font-weight:800;letter-spacing:.12em;text-transform:uppercase}.card h2{font-size:28px;margin:9px 0 8px}.muted{color:#64748b;line-height:1.55;margin:0 0 24px}.btn{width:100%;border:0;border-radius:11px;padding:13px 16px;font-size:15px;font-weight:700;cursor:pointer;background:#2563eb;color:#fff}.status{margin-top:18px;padding:12px;border-radius:10px;background:#f8fafc;border:1px solid #e2e8f0;font-size:12px;color:#475569;line-height:1.6}.notice{margin-top:18px;padding:12px;border-radius:10px;background:#fffbeb;border:1px solid #fde68a;color:#92400e;font-size:12px;line-height:1.55}
        @media(max-width:880px){.shell{grid-template-columns:1fr}.brand{padding:38px 28px}.brand h1{font-size:34px}.login{padding:28px 18px}.card{padding:26px}}
    </style>
</head>
<body>
<form id="form1" runat="server">
<div class="shell">
    <section class="brand">
        <div class="mark">Babco AI</div>
        <h1>SQL AI Agent Control &amp; Analytics</h1>
        <p>Natural-language SQL analysis, AI usage telemetry, token cost visibility and Admin Agent Flow console.</p>
        <div class="points">
            <div class="point"><span class="dot"></span><span>Temporary testing access</span></div>
            <div class="point"><span class="dot"></span><span>Read-only SQL execution guardrails</span></div>
            <div class="point"><span class="dot"></span><span>Per-request token and USD cost tracking</span></div>
        </div>
    </section>
    <section class="login">
        <div class="card">
            <div class="eyebrow">Prototype / Test Access</div>
            <h2>Temporary Admin Login</h2>
            <p class="muted">Microsoft Entra sign-in is temporarily disabled so application testing can continue. This page automatically opens an Admin testing session.</p>
            <asp:Button ID="btnTestLogin" runat="server" Text="Continue to SQL AI Agent" CssClass="btn" OnClick="btnTestLogin_Click" />
            <div class="status"><asp:Literal ID="litConfigStatus" runat="server"></asp:Literal></div>
            <div class="notice">Testing mode only. SQL and OpenAI credentials remain server-side and unchanged.</div>
        </div>
    </section>
</div>
</form>
</body>
</html>
