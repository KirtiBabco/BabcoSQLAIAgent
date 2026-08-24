<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.ContentType = "text/plain";
        Response.TrySkipIisCustomErrors = true;
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        Response.Cache.SetNoStore();

        string expected = Environment.GetEnvironmentVariable("BAP_HEALTH_TOKEN");
        string supplied = Request.Headers["X-Babco-Health-Token"];
        if (string.IsNullOrWhiteSpace(expected) || !string.Equals(expected, supplied, StringComparison.Ordinal))
        {
            Response.StatusCode = 404;
            Response.Write("NOT_FOUND");
            return;
        }

        bool sqlOk = false;
        string sqlError = "";
        int tableCount = -1;
        try
        {
            using (var connection = new SqlConnection(SQL_AI_Agent.AppConfig.SqlConnectionString))
            {
                connection.Open();
                using (var command = connection.CreateCommand())
                {
                    command.CommandTimeout = 10;
                    command.CommandText = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES";
                    tableCount = Convert.ToInt32(command.ExecuteScalar());
                }
            }
            sqlOk = true;
        }
        catch (Exception ex)
        {
            sqlError = Safe(ex.Message);
        }

        bool openAiOk = false;
        string openAiError = "";
        try
        {
            string reply = new SQL_AI_Agent.OpenAIClient().Chat("You are a backend health check.", "Reply only OK.");
            openAiOk = !string.IsNullOrWhiteSpace(reply);
        }
        catch (Exception ex)
        {
            openAiError = Safe(ex.Message);
        }

        Response.Write("HEALTH_PAGE_OK=true\n");
        Response.Write("SQL_OK=" + sqlOk.ToString().ToLowerInvariant() + "\n");
        Response.Write("SQL_TABLE_COUNT=" + (tableCount < 0 ? "" : tableCount.ToString()) + "\n");
        Response.Write("SQL_ERROR=" + sqlError + "\n");
        Response.Write("OPENAI_OK=" + openAiOk.ToString().ToLowerInvariant() + "\n");
        Response.Write("OPENAI_ERROR=" + openAiError + "\n");
    }

    private static string Safe(string value)
    {
        if (string.IsNullOrEmpty(value)) return "";
        value = value.Replace("\r", " ").Replace("\n", " ").Trim();
        return value.Length > 500 ? value.Substring(0, 500) : value;
    }
</script>
