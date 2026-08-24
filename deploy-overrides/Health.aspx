<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Net" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="SQL_AI_Agent" %>
<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "text/plain";
    try
    {
        var cs = AppConfig.SqlConnectionString;
        using (var c = new SqlConnection(cs))
        {
            c.Open();
            using (var cmd = c.CreateCommand())
            {
                cmd.CommandText = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES";
                cmd.CommandTimeout = 15;
                var n = cmd.ExecuteScalar();
                Response.Write("SQL_OK=true\nSQL_TABLE_COUNT=" + Convert.ToString(n) + "\n");
            }
        }
    }
    catch (Exception ex)
    {
        Response.Write("SQL_OK=false\nSQL_ERROR_TYPE=" + ex.GetType().Name + "\n");
    }

    try
    {
        var key = AppConfig.OpenAIApiKey;
        var request = (HttpWebRequest)WebRequest.Create("https://api.openai.com/v1/responses");
        request.Method = "POST";
        request.ContentType = "application/json";
        request.Headers[HttpRequestHeader.Authorization] = "Bearer " + key;
        request.Timeout = 30000;
        var body = Encoding.UTF8.GetBytes("{\"model\":\"gpt-5-mini\",\"input\":\"Reply only OK\",\"max_output_tokens\":16}");
        using (var s = request.GetRequestStream()) s.Write(body, 0, body.Length);
        using (var r = (HttpWebResponse)request.GetResponse()) Response.Write("OPENAI_OK=" + (((int)r.StatusCode >= 200 && (int)r.StatusCode < 300) ? "true" : "false") + "\nOPENAI_HTTP=" + (int)r.StatusCode + "\n");
    }
    catch (Exception ex)
    {
        Response.Write("OPENAI_OK=false\nOPENAI_ERROR_TYPE=" + ex.GetType().Name + "\n");
    }
}
</script>
