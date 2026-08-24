<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="SQL_AI_Agent.Default" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>SQL AI Agent</title>
    <style>
        *{box-sizing:border-box}
        body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:#f4f7fb;color:#1f2937}
        .top{background:linear-gradient(135deg,#172554,#2563eb);color:#fff;padding:18px 28px}
        .topin,.wrap{max-width:1100px;margin:auto}
        .topin{display:flex;justify-content:space-between;align-items:center;gap:16px}.account{display:flex;align-items:center;gap:8px;flex-wrap:wrap;justify-content:flex-end}.useremail{font-size:12px;opacity:.9}.rolebadge{padding:7px 10px;border-radius:16px;background:rgba(255,255,255,.15);font-size:12px;font-weight:700}.rolebadge.admin{background:#dcfce7;color:#166534}.navbtn{display:inline-block;padding:8px 11px;border-radius:18px;border:1px solid rgba(255,255,255,.28);background:rgba(255,255,255,.12);color:#fff;text-decoration:none;font-size:12px;font-weight:600}.navbtn.adminlink{background:#fef3c7;color:#92400e;border-color:#fde68a}
        .brand{font-size:23px;font-weight:700}.sub{font-size:12px;opacity:.85;margin-top:3px}
        .status{padding:8px 12px;border:1px solid rgba(255,255,255,.25);border-radius:18px;background:rgba(255,255,255,.12);font-size:12px}
        .wrap{padding:28px 18px}
        .card{background:#fff;border-radius:14px;padding:22px;margin-bottom:18px;box-shadow:0 5px 25px rgba(15,23,42,.08)}
        h2{margin:0 0 7px;font-size:22px}.muted{margin:0;color:#64748b}
        .prompt{position:relative;margin-top:18px}
        textarea{width:100%;min-height:130px;resize:vertical;border:1px solid #cbd5e1;border-radius:12px;padding:16px 58px 16px 16px;font-size:16px;line-height:1.5;outline:none}
        textarea:focus{border-color:#2563eb;box-shadow:0 0 0 3px rgba(37,99,235,.1)}
        .mic{position:absolute;right:12px;top:12px;width:40px;height:40px;border:0;border-radius:50%;background:#eff6ff;color:#1d4ed8;font-size:20px;cursor:pointer}
        .mic.listening{background:#fee2e2;color:#dc2626}
        .bar{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-top:12px}
        select,.btn{border-radius:9px;padding:10px 14px;font-size:14px}
        select{border:1px solid #cbd5e1;background:#fff}
        .btn{border:0;cursor:pointer;font-weight:600}.primary{background:#2563eb;color:#fff}.secondary{background:#e2e8f0;color:#334155}
        .speak{background:#ecfdf5;color:#047857}.stop{background:#fef2f2;color:#b91c1c}
        .hint{font-size:12px;color:#64748b;margin-left:auto}
        .loading{display:none;margin-top:14px;color:#2563eb;font-size:14px}
        .answer{display:none}.answerhead{display:flex;justify-content:space-between;align-items:center;gap:12px}
        .answerbox{white-space:pre-wrap;background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:16px;min-height:80px;line-height:1.55;margin-top:12px}
        .error{display:none;margin-top:12px;padding:12px;border-radius:10px;background:#fef2f2;border:1px solid #fecaca;color:#991b1b;white-space:pre-wrap}
        .examples{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}.ex{padding:7px 11px;border-radius:18px;background:#f1f5f9;border:1px solid #e2e8f0;color:#475569;font-size:12px;cursor:pointer}
        .footer{text-align:center;color:#94a3b8;font-size:12px;padding:4px 0 20px}
        @media(max-width:700px){.topin{flex-direction:column;align-items:flex-start}.account{justify-content:flex-start}.hint{margin-left:0;width:100%}}
    </style>
</head>
<body>
<form id="form1" runat="server">
<div class="top"><div class="topin">
    <div><div class="brand">🧠 SQL AI Agent</div><div class="sub">ASP.NET Web Forms • .NET Framework 4.8 • OpenAI GPT • SQL Server Read Only</div></div>
    <div class="account">
        <span class="useremail"><%= Server.HtmlEncode(SQL_AI_Agent.AuthService.CurrentUserEmail) %></span>
        <span class="rolebadge <%= SQL_AI_Agent.AuthService.IsAdmin ? "admin" : "" %>"><%= SQL_AI_Agent.AuthService.IsAdmin ? "Admin" : "User" %></span>
        <% if (SQL_AI_Agent.AuthService.IsAdmin) { %><a class="navbtn adminlink" href="Admin.aspx">💰 Costing / Admin</a><% } %>
        <a class="navbtn" href="/.auth/logout?post_logout_redirect_uri=%2FLogin.aspx">Logout</a>
        <span class="status">&#9679; AI Agent Ready</span>
    </div>
</div></div>

<div class="wrap">
    <div class="card">
        <h2>Ask your SQL Database</h2>
        <p class="muted">Type or speak your question in any supported language. The Agent will check the database and answer.</p>
        <div class="prompt">
            <textarea id="txtPrompt" placeholder="Example: Total Items Kitni Hai?"></textarea>
            <button type="button" id="btnMic" class="mic" title="Speak your question">🎤</button>
        </div>
        <div class="bar">
            <select id="ddlLanguage">
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
            <span class="hint">🎤 Speak → text appears → Ask AI Agent</span>
        </div>
        <div class="examples">
            <span class="ex">Total Items Kitni Hai?</span>
            <span class="ex">Total Users Kitne Hai?</span>
            <span class="ex">Show top 10 products</span>
            <span class="ex">Gujarati ma total pending orders batao</span>
        </div>
        <div id="loading" class="loading">⏳ Agent is checking SQL and preparing your answer...</div>
        <div id="errorBox" class="error"></div>
    </div>

    <div id="answerCard" class="card answer">
        <div class="answerhead">
            <h3>🤖 Agent Answer</h3>
            <div>
                <button type="button" id="btnSpeak" class="btn speak">🔊 Speak</button>
                <button type="button" id="btnStop" class="btn stop">⏹ Stop</button>
            </div>
        </div>
        <div id="answerBox" class="answerbox"></div>
    </div>

    <div class="footer">SQL AI Agent • OpenAI GPT • Read-only SQL Tool</div>
</div>
</form>

<script>
(function(){
    var recognition=null, listening=false;
    function id(x){return document.getElementById(x);}
    function error(msg){var e=id("errorBox");e.textContent=msg||"Request failed.";e.style.display="block";}
    function clearError(){var e=id("errorBox");e.textContent="";e.style.display="none";}
    function loading(v){id("loading").style.display=v?"block":"none";id("btnAsk").disabled=v;}

    function escapeHtml(text){
        return String(text).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")
            .replace(/"/g,"&quot;").replace(/'/g,"&#39;");
    }
    function formatAnswer(text){
        var safe = escapeHtml(text);
        safe = safe.replace(/\\*\\*(.*?)\\*\\*/g, "<strong>$1</strong>");
        return safe.replace(/\\r?\\n/g, "<br>");
    }

    function ask(){
        var prompt=id("txtPrompt").value.trim();
        if(!prompt){error("Please enter or speak a question first.");return;}
        clearError();loading(true);id("answerCard").style.display="none";
        fetch("Default.aspx/AskAgent",{
            method:"POST",
            headers:{"Content-Type":"application/json; charset=utf-8"},
            body:JSON.stringify({prompt:prompt})
        }).then(function(r){
            return r.text().then(function(t){
                var d;try{d=JSON.parse(t);}catch(e){throw new Error(t||"Invalid server response.");}
                if(!r.ok){throw new Error((d&&d.Message)||t);}
                return d;
            });
        }).then(function(d){
            loading(false);
            var result=(d&&d.d!==undefined)?d.d:d;
            id("answerBox").innerHTML = formatAnswer(result || "No answer returned.");
            id("answerCard").style.display="block";
            id("answerCard").scrollIntoView({behavior:"smooth",block:"start"});
        }).catch(function(e){loading(false);error(e.message||"Agent request failed.");});
    }

    function voice(){
        var SR=window.SpeechRecognition||window.webkitSpeechRecognition;
        if(!SR){error("Voice input is not supported by this browser. Use current Chrome or Edge.");return;}
        if(listening){recognition.stop();return;}
        recognition=new SR();recognition.continuous=false;recognition.interimResults=true;
        recognition.lang=id("ddlLanguage").value||navigator.language||"en-IN";
        recognition.onstart=function(){listening=true;id("btnMic").classList.add("listening");id("btnMic").textContent="⏹";clearError();};
        recognition.onresult=function(e){var t="";for(var i=e.resultIndex;i<e.results.length;i++)t+=e.results[i][0].transcript;id("txtPrompt").value=t;};
        recognition.onerror=function(e){error("Voice input error: "+e.error);};
        recognition.onend=function(){listening=false;id("btnMic").classList.remove("listening");id("btnMic").textContent="🎤";};
        recognition.start();
    }

    function speak(){
        if(!("speechSynthesis" in window)){error("Text-to-speech is not supported by this browser.");return;}
        var text=id("answerBox").innerText.trim();if(!text)return;
        speechSynthesis.cancel();
        var u=new SpeechSynthesisUtterance(text);u.rate=1;u.pitch=1;u.volume=1;
        var voices=speechSynthesis.getVoices(), lang=(navigator.language||"en-US").split("-")[0].toLowerCase();
        for(var i=0;i<voices.length;i++){if((voices[i].lang||"").toLowerCase().indexOf(lang)===0){u.voice=voices[i];break;}}
        speechSynthesis.speak(u);
    }
    function stop(){if("speechSynthesis"in window)speechSynthesis.cancel();}

    document.addEventListener("DOMContentLoaded",function(){
        id("btnAsk").onclick=ask;id("btnMic").onclick=voice;id("btnSpeak").onclick=speak;id("btnStop").onclick=stop;
        id("btnClear").onclick=function(){stop();id("txtPrompt").value="";id("answerBox").textContent="";id("answerCard").style.display="none";clearError();};
        var ex=document.querySelectorAll(".ex");for(var i=0;i<ex.length;i++){ex[i].onclick=function(){id("txtPrompt").value=this.textContent;id("txtPrompt").focus();};}
    });
})();
</script>
</body>
</html>
