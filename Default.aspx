<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="SQL_AI_Agent.Default" %>
<!DOCTYPE html>
<html lang="en">
<head runat="server">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Babco SQL AI Agent</title>
<style>
*{box-sizing:border-box}body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:#f4f7fb;color:#172033}.top{background:#172554;color:#fff;padding:16px 24px;display:flex;justify-content:space-between;align-items:center}.top h1{font-size:20px;margin:0}.wrap{max-width:1180px;margin:28px auto;padding:0 20px}.card{background:#fff;border:1px solid #e2e8f0;border-radius:16px;padding:22px;box-shadow:0 12px 35px rgba(15,23,42,.08)}textarea{width:100%;min-height:110px;padding:14px;border:1px solid #cbd5e1;border-radius:10px;font:14px Segoe UI,Arial;resize:vertical}.actions{display:flex;gap:10px;margin-top:12px;align-items:center;flex-wrap:wrap}.btn{border:0;border-radius:10px;background:#2563eb;color:#fff;padding:11px 18px;font-weight:700;cursor:pointer}.btn:disabled{opacity:.55}.voice-btn{border:1px solid #cbd5e1;border-radius:10px;background:#fff;color:#172033;padding:10px 14px;font-weight:700;cursor:pointer;display:inline-flex;align-items:center;gap:7px}.voice-btn.active{background:#fee2e2;border-color:#fca5a5;color:#991b1b}.voice-btn:disabled{opacity:.5;cursor:not-allowed}.result{margin-top:18px;padding:16px;border-radius:10px;background:#0f172a;color:#e2e8f0;white-space:pre-wrap;min-height:140px;overflow:auto}.note{color:#64748b;font-size:13px;margin-top:8px}.voice-note{font-size:12px;color:#64748b}.status{display:inline-block;background:#dcfce7;color:#166534;padding:5px 9px;border-radius:999px;font-size:12px;font-weight:700}
</style>
</head>
<body>
<form id="form1" runat="server">
<div class="top"><h1>Babco SQL AI Agent</h1><span class="status">Signed in</span></div>
<div class="wrap"><div class="card">
<h2>Ask the Babco database</h2>
<p class="note">The agent generates and executes read-only SELECT queries only.</p>
<textarea id="prompt" placeholder="Example: Show the top 20 items by brand..."></textarea>
<div class="actions">
<button type="button" id="ask" class="btn" onclick="askAgent()">Ask AI Agent</button>
<button type="button" id="mic" class="voice-btn" onclick="toggleMic()" title="Speak your question">🎤 <span id="micText">Mic</span></button>
<button type="button" id="speaker" class="voice-btn" onclick="speakResult()" title="Read the answer aloud">🔊 Speaker</button>
<button type="button" id="stopSpeaker" class="voice-btn" onclick="stopSpeaking()" title="Stop speaking">⏹ Stop</button>
<span id="voiceStatus" class="voice-note">Mic and speaker use browser-managed audio and do not keep the device locked.</span>
</div>
<div id="result" class="result">Ready.</div>
</div></div>
<script>
var recognition=null,isListening=false;
function askAgent(){var p=document.getElementById('prompt').value.trim(),b=document.getElementById('ask'),r=document.getElementById('result');if(!p){r.textContent='Please enter a question.';return;}b.disabled=true;r.textContent='Working...';fetch('Default.aspx/AskAgent',{method:'POST',headers:{'Content-Type':'application/json; charset=utf-8'},credentials:'same-origin',body:JSON.stringify({prompt:p})}).then(function(x){return x.json().then(function(j){if(!x.ok)throw new Error((j&&j.Message)||('HTTP '+x.status));return j;});}).then(function(j){r.textContent=j.d||'';}).catch(function(e){r.textContent='Error: '+e.message;}).finally(function(){b.disabled=false;});}
function getRecognition(){if(recognition)return recognition;var SR=window.SpeechRecognition||window.webkitSpeechRecognition;if(!SR)return null;recognition=new SR();recognition.continuous=false;recognition.interimResults=true;recognition.lang=(navigator.language||'en-US');recognition.onstart=function(){isListening=true;setMicState(true,'Listening…');};recognition.onresult=function(e){var text='';for(var i=e.resultIndex;i<e.results.length;i++){text+=e.results[i][0].transcript;}if(text){document.getElementById('prompt').value=text.trim();}setVoiceStatus('Listening… speak naturally.');};recognition.onerror=function(e){setVoiceStatus(e.error==='audio-capture'?'Microphone is busy or unavailable. Teams can remain open; try Mic again.':'Mic: '+e.error);};recognition.onend=function(){isListening=false;setMicState(false,'Mic');setVoiceStatus('Mic released. Ready.');};return recognition;}
function toggleMic(){var r=getRecognition();if(!r){setVoiceStatus('Speech recognition is not supported in this browser. Use Edge or Chrome.');return;}try{if(isListening){r.stop();}else{if(window.speechSynthesis)window.speechSynthesis.cancel();r.start();}}catch(e){setVoiceStatus('Mic is already changing state. Try again.');}}
function setMicState(active,text){var b=document.getElementById('mic');b.className=active?'voice-btn active':'voice-btn';document.getElementById('micText').textContent=text;}
function speakResult(){var text=document.getElementById('result').textContent.trim();if(!text||text==='Ready.'||text==='Working...'){setVoiceStatus('No answer to read yet.');return;}if(!('speechSynthesis'in window)){setVoiceStatus('Speaker is not supported in this browser.');return;}window.speechSynthesis.cancel();var u=new SpeechSynthesisUtterance(text);u.lang=navigator.language||'en-US';u.rate=1;u.onstart=function(){setVoiceStatus('Speaking…');};u.onend=function(){setVoiceStatus('Speaker finished.');};u.onerror=function(){setVoiceStatus('Speaker could not play the response.');};window.speechSynthesis.speak(u);}
function stopSpeaking(){if(window.speechSynthesis)window.speechSynthesis.cancel();setVoiceStatus('Speaker stopped.');}
function setVoiceStatus(t){document.getElementById('voiceStatus').textContent=t;}
window.addEventListener('beforeunload',function(){try{if(recognition&&isListening)recognition.stop();}catch(e){}if(window.speechSynthesis)window.speechSynthesis.cancel();});
</script>
</form>
</body>
</html>
