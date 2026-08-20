<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="SQL_AI_Agent.Default" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Babco SQL AI Agent</title>
<style>
*{box-sizing:border-box}body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:#f4f7fb;color:#172033}.top{background:#172554;color:#fff;padding:16px 24px;display:flex;justify-content:space-between;align-items:center}.top h1{font-size:20px;margin:0}.wrap{max-width:1180px;margin:28px auto;padding:0 20px}.card{background:#fff;border:1px solid #e2e8f0;border-radius:16px;padding:22px;box-shadow:0 12px 35px rgba(15,23,42,.08)}textarea{width:100%;min-height:110px;padding:14px;border:1px solid #cbd5e1;border-radius:10px;font:14px Segoe UI,Arial;resize:vertical}.actions{display:flex;gap:10px;margin-top:12px}.btn{border:0;border-radius:10px;background:#2563eb;color:#fff;padding:11px 18px;font-weight:700;cursor:pointer}.btn:disabled{opacity:.55}.result{margin-top:18px;padding:16px;border-radius:10px;background:#0f172a;color:#e2e8f0;white-space:pre-wrap;min-height:140px;overflow:auto}.note{color:#64748b;font-size:13px;margin-top:8px}.status{display:inline-block;background:#dcfce7;color:#166534;padding:5px 9px;border-radius:999px;font-size:12px;font-weight:700}
</style>
</head>
<body>
<form id="form1" runat="server">
<div class="top"><h1>Babco SQL AI Agent</h1><span class="status">Signed in</span></div>
<div class="wrap"><div class="card">
<h2>Ask the Babco database</h2>
<p class="note">The agent generates and executes read-only SELECT queries only.</p>
<textarea id="prompt" placeholder="Example: Show the top 20 items by brand..."></textarea>
<div class="actions"><button type="button" id="ask" class="btn" onclick="askAgent()">Ask AI Agent</button></div>
<div id="result" class="result">Ready.</div>
</div></div>
<script>
function askAgent(){var p=document.getElementById('prompt').value.trim(),b=document.getElementById('ask'),r=document.getElementById('result');if(!p){r.textContent='Please enter a question.';return;}b.disabled=true;r.textContent='Working...';fetch('Default.aspx/AskAgent',{method:'POST',headers:{'Content-Type':'application/json; charset=utf-8'},credentials:'same-origin',body:JSON.stringify({prompt:p})}).then(function(x){return x.json().then(function(j){if(!x.ok)throw new Error((j&&j.Message)||('HTTP '+x.status));return j;});}).then(function(j){r.textContent=j.d||'';}).catch(function(e){r.textContent='Error: '+e.message;}).finally(function(){b.disabled=false;});}
</script>
</form>
</body>
</html>
