using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using System.Web.Script.Serialization;

namespace SQL_AI_Agent
{
    public sealed class OpenAIClient
    {
        private readonly JavaScriptSerializer _json = new JavaScriptSerializer();

        public string Chat(string systemPrompt, string userPrompt)
        {
            var request = (HttpWebRequest)WebRequest.Create(AppConfig.OpenAIUrl);
            request.Method = "POST";
            request.ContentType = "application/json";
            request.Accept = "application/json";
            request.Timeout = 30000;
            request.ReadWriteTimeout = 30000;
            request.Headers["Authorization"] = "Bearer " + AppConfig.OpenAIApiKey;

            var payload = new
            {
                model = AppConfig.OpenAIModel,
                input = new object[]
                {
                    new { role = "developer", content = new object[] { new { type = "input_text", text = systemPrompt } } },
                    new { role = "user", content = new object[] { new { type = "input_text", text = userPrompt } } }
                }
            };

            byte[] bytes = Encoding.UTF8.GetBytes(_json.Serialize(payload));
            request.ContentLength = bytes.Length;
            using (var stream = request.GetRequestStream()) stream.Write(bytes, 0, bytes.Length);

            try
            {
                using (var response = (HttpWebResponse)request.GetResponse())
                using (var reader = new StreamReader(response.GetResponseStream()))
                    return ExtractOutputText(reader.ReadToEnd());
            }
            catch (WebException ex)
            {
                string details = ex.Message;
                if (ex.Response != null)
                    using (var reader = new StreamReader(ex.Response.GetResponseStream())) details += Environment.NewLine + reader.ReadToEnd();
                throw new Exception("OPENAI API ERROR" + Environment.NewLine + "Model: " + AppConfig.OpenAIModel + Environment.NewLine + "Details: " + details, ex);
            }
        }

        private string ExtractOutputText(string responseText)
        {
            var root = _json.DeserializeObject(responseText) as Dictionary<string, object>;
            if (root == null) throw new Exception("OpenAI returned invalid JSON.");
            if (root.ContainsKey("error") && root["error"] != null) throw new Exception("OpenAI returned an error.");
            if (root.ContainsKey("output_text") && root["output_text"] != null) return Convert.ToString(root["output_text"]);
            object outputObj;
            if (root.TryGetValue("output", out outputObj))
            {
                var output = outputObj as object[];
                if (output != null)
                {
                    var sb = new StringBuilder();
                    foreach (object itemObj in output)
                    {
                        var item = itemObj as Dictionary<string, object>;
                        if (item == null) continue;
                        object contentObj;
                        if (!item.TryGetValue("content", out contentObj)) continue;
                        var content = contentObj as object[];
                        if (content == null) continue;
                        foreach (object partObj in content)
                        {
                            var part = partObj as Dictionary<string, object>;
                            if (part == null) continue;
                            object text;
                            if (part.TryGetValue("text", out text) && text != null) sb.Append(Convert.ToString(text));
                        }
                    }
                    if (sb.Length > 0) return sb.ToString();
                }
            }
            throw new Exception("OpenAI response did not contain output text.");
        }
    }
}
