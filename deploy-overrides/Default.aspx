<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="SQL_AI_Agent.Default" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <title>Babco Labs - SQL AI Agent</title>
    <link rel="stylesheet" href="SqlAgent0106.css?v=20260901.1" />
</head>
<body>
<form id="form1" runat="server">
<div class="prototypeRibbon">PROTOTYPE</div>
<header class="finalHeader">
    <div class="finalBrand">
        <div class="brandMark">B</div>
        <div>
            <span class="eyebrow">BABCO LABS · 0106 EXPERIENCE</span>
            <h1>SQL AI Agent</h1>
            <p>Natural-language SQL analysis · OpenAI · Read-only database access</p>
        </div>
    </div>
    <div class="finalHeaderState">
        <span class="statePill"><i></i> Secure SQL + AI workspace</span>
        <span class="statePill"><%= Server.HtmlEncode(SQL_AI_Agent.AuthService.CurrentUserEmail) %> · <%= SQL_AI_Agent.AuthService.IsAdmin ? "Admin" : "User" %></span>
        <a class="headerBtn" href="Default.aspx" title="Refresh">↻</a>
        <a class="headerBtn" href="/.auth/logout?post_logout_redirect_uri=%2FLogin.aspx">Logout</a>
    </div>
</header>
<nav class="finalNav" aria-label="Primary navigation">
    <a class="finalNavItem" href="#today"><span>✦</span> Today</a>
    <a class="finalNavItem active" href="#agent"><span>⌁</span> SQL Agent</a>
    <% if (SQL_AI_Agent.AuthService.IsAdmin) { %><a class="finalNavItem" href="Admin.aspx"><span>◫</span> Cost</a><% } %>
    <a class="finalNavItem" href="Help.aspx"><span>?</span> Help</a>
    <a class="finalNavItem" href="Standard.aspx"><span>▣</span> Standard</a>
    <a class="finalNavItem" href="Diagnostics.aspx"><span>⚙</span> Diagnostics</a>
</nav>
<section id="today" class="dailyPulse" aria-label="Daily SQL AI status">
    <div class="pulseIntro"><span>MY SQL AI DAY</span><strong id="todayDate">Today</strong></div>
    <div class="pulseCard accent"><span>SQL Mode</span><strong>RO</strong><small>Read only</small></div>
    <div class="pulseCard ai"><span>AI Agent</span><strong>ON</strong><small>OpenAI ready</small></div>
    <div class="pulseCard"><span>Voice</span><strong>✓</strong><small>Mic + speaker</small></div>
    <div class="pulseCard"><span>Access</span><strong><%= SQL_AI_Agent.AuthService.IsAdmin ? "A" : "U" %></strong><small><%= SQL_AI_Agent.AuthService.IsAdmin ? "Admin" : "User" %></small></div>
</section>
<main class="page">
    <section class="hero">
        <div><h2>Ask the Babco database</h2><p class="muted">Same APP-BAB-0106 workspace style, focused only on SQL + AI. Outlook and Teams are intentionally not included.</p></div>
        <span class="tag">Human question → read-only SQL → answer</span>
    </section>
    <div class="grid2">
        <section id="agent" class="card">
            <div class="panelHead">
                <div><h3>Ask Babco SQL AI</h3><p class="muted">Type or speak your question. The agent generates safe SELECT queries and returns the result.</p></div>
                <span class="tag">AI Agent Ready</span>
            </div>
            <div class="promptBox">
                <textarea id="txtPrompt" placeholder="Example: Show the top 20 items by brand..."></textarea>
                <button type="button" id="btnMic" class="mic" title="Speak your question">🎤</button>
            </div>
            <div class="toolbar">
                <select id="ddlLanguage" class="select">
                    <option value="">Auto / Browser Default</option>
                    <option value="en-IN">English (India)</option>
                    <option value="hi-IN">Hindi</option>
                    <option value="gu-IN">Gujarati</option>
                    <option value="mr-IN">Marathi</option>
                    <option value="bn-IN">Bengali</option>
                    <option value="ta-IN">Tamil</option>
                    <option value="te-IN">Telugu</option>
                    <option value="pa-IN">Punjabi</option>
                    <option value="en-US">English (US)</option>
                    <option value="es-ES">Spanish</option>
                    <option value="fr-FR">French</option>
                    <option value="de-DE">German</option>
                </select>
                <button type="button" id="btnAsk" class="btn primary">Ask AI Agent</button>
                <button type="button" id="btnClear" class="btn secondary">Clear</button>
                <button type="button" id="btnSpeak" class="btn speaker">🔊 Speak Answer</button>
                <button type="button" id="btnStop" class="btn danger">⏹ Stop</button>
            </div>
            <div class="examples" style="margin-top:12px">
                <button type="button" class="example">Total Items Kitni Hai?</button>
                <button type="button" class="example">Show top 10 products</button>
                <button type="button" class="example">Total Users Kitne Hai?</button>
                <button type="button" class="example">Gujarati ma pending orders batao</button>
            </div>
            <div id="loading" class="loading">Agent is checking SQL and preparing your answer...</div>
            <div id="errorBox" class="error"></div>
            <div style="margin-top:14px"><div class="panelHead"><div><h3>Agent Answer</h3><p class="muted">Read-only result from the SQL AI flow.</p></div></div><div id="answerBox" class="answerBox">Ready.</div></div>
        </section>
        <aside class="stack">
            <section class="card">
                <div class="panelHead"><div><h3>Workspace</h3><p class="muted">0106-style quick navigation, adapted for this application.</p></div></div>
                <div class="quickList">
                    <% if (SQL_AI_Agent.AuthService.IsAdmin) { %><a class="quickLink" href="Admin.aspx"><strong>AI Usage & Cost</strong><small>Model, key status, SQL setting and configured rate card.</small></a><% } %>
                    <a class="quickLink" href="Diagnostics.aspx"><strong>Monitoring & Diagnostics</strong><small>Live application health checks and runtime verification.</small></a>
                    <a class="quickLink" href="Help.aspx"><strong>Help</strong><small>How to use SQL AI, microphone, speaker and safe query rules.</small></a>
                    <a class="quickLink" href="Standard.aspx"><strong>Prototype Standard</strong><small>Scope, security rules and APP-BAB-0106 reference pattern.</small></a>
                </div>
            </section>
            <section class="card">
                <div class="panelHead"><div><h3>Safety</h3></div><span class="tag">Read only</span></div>
                <p class="muted" style="line-height:1.6;margin:0">The SQL tool is restricted to read-only SELECT analysis. Credentials remain server-side. Email and Teams integrations are not part of this site.</p>
            </section>
        </aside>
    </div>
    <div class="footer">Internal Use Only · Babco Labs Prototype · SQL AI Agent · APP-BAB-0106 visual/functionality reference</div>
</main>
</form>
<script>
(function(){
    var recognition=null,listening=false;
    function id(x){return document.getElementById(x)}
    function showError(msg){var e=id('errorBox');e.textContent=msg||'Request failed.';e.style.display='block'}
    function clearError(){var e=id('errorBox');e.textContent='';e.style.display='none'}
    function busy(v){id('loading').style.display=v?'block':'none';id('btnAsk').disabled=v}
    function ask(){var p=id('txtPrompt').value.trim();if(!p){showError('Please enter or speak a question first.');return}clearError();busy(true);id('answerBox').textContent='Working...';fetch('Default.aspx/AskAgent',{method:'POST',headers:{'Content-Type':'application/json; charset=utf-8'},credentials:'same-origin',body:JSON.stringify({prompt:p})}).then(function(r){return r.text().then(function(t){var d;try{d=JSON.parse(t)}catch(e){throw new Error(t||'Invalid server response.')}if(!r.ok)throw new Error((d&&d.Message)||t);return d})}).then(function(d){busy(false);id('answerBox').textContent=(d&&d.d!==undefined?d.d:d)||'No answer returned.'}).catch(function(e){busy(false);id('answerBox').textContent='Ready.';showError(e.message||'Agent request failed.')})}
    function voice(){var SR=window.SpeechRecognition||window.webkitSpeechRecognition;if(!SR){showError('Voice input is not supported by this browser. Use current Chrome or Edge.');return}if(listening){recognition.stop();return}recognition=new SR();recognition.continuous=false;recognition.interimResults=true;recognition.lang=id('ddlLanguage').value||navigator.language||'en-IN';recognition.onstart=function(){listening=true;id('btnMic').classList.add('listening');id('btnMic').textContent='⏹';clearError()};recognition.onresult=function(e){var t='';for(var i=e.resultIndex;i<e.results.length;i++)t+=e.results[i][0].transcript;id('txtPrompt').value=t};recognition.onerror=function(e){showError('Voice input error: '+e.error)};recognition.onend=function(){listening=false;id('btnMic').classList.remove('listening');id('btnMic').textContent='🎤'};recognition.start()}
    function speak(){if(!('speechSynthesis' in window)){showError('Speaker is not supported by this browser.');return}var t=id('answerBox').innerText.trim();if(!t||t==='Ready.'||t==='Working...')return;speechSynthesis.cancel();var u=new SpeechSynthesisUtterance(t);u.lang=id('ddlLanguage').value||navigator.language||'en-US';speechSynthesis.speak(u)}
    function stop(){if('speechSynthesis' in window)speechSynthesis.cancel()}
    document.addEventListener('DOMContentLoaded',function(){var d=new Date();id('todayDate').textContent=d.toLocaleDateString(undefined,{weekday:'long',month:'short',day:'numeric'});id('btnAsk').onclick=ask;id('btnMic').onclick=voice;id('btnSpeak').onclick=speak;id('btnStop').onclick=stop;id('btnClear').onclick=function(){stop();id('txtPrompt').value='';id('answerBox').textContent='Ready.';clearError()};var ex=document.querySelectorAll('.example');for(var i=0;i<ex.length;i++)ex[i].onclick=function(){id('txtPrompt').value=this.textContent;id('txtPrompt').focus()};id('txtPrompt').addEventListener('keydown',function(e){if((e.ctrlKey||e.metaKey)&&e.key==='Enter')ask()})})
})();
</script>
</body>
</html>
