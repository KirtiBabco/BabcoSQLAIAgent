using System;
using System.Data.SqlClient;
using System.Text;
using System.Web;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class Login : Page
    {
        private bool _healthMode;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (TryRunHealthCheck()) return;

            litConfigStatus.Text = "<strong>Entra:</strong> Azure App Service Easy Auth &nbsp; | &nbsp; <strong>Admin list:</strong> " +
                (string.IsNullOrWhiteSpace(AppConfig.AdminEmails) ? "Not set (all Entra users are standard users)" : "Configured");

            if (!IsPostBack && AuthService.BootstrapEasyAuthSession(Request))
            {
                Response.Redirect("~/Default.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
        }

        protected override void Render(HtmlTextWriter writer)
        {
            if (_healthMode) return;
            base.Render(writer);
        }

        private bool TryRunHealthCheck()
        {
            if (!string.Equals(Request.QueryString["health"], "1", StringComparison.Ordinal)) return false;

            string expected = Environment.GetEnvironmentVariable("BAP_HEALTH_TOKEN");
            string supplied = Request.Headers["X-Babco-Health-Token"];
            _healthMode = true;
            Response.Clear();
            Response.ContentType = "text/plain";
            Response.TrySkipIisCustomErrors = true;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();

            if (string.IsNullOrWhiteSpace(expected) || !string.Equals(expected, supplied, StringComparison.Ordinal))
            {
                Response.StatusCode = 404;
                Response.Write("NOT_FOUND");
                Context.ApplicationInstance.CompleteRequest();
                return true;
            }

            bool sqlOk = false;
            int tableCount = -1;
            string sqlErrorType = "";
            string sqlErrorNumber = "";
            string sqlClassification = "";
            try
            {
                var builder = new SqlConnectionStringBuilder(AppConfig.SqlConnectionString);
                builder.ConnectTimeout = 10;
                using (var connection = new SqlConnection(builder.ConnectionString))
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
                sqlClassification = "OK";
            }
            catch (Exception ex)
            {
                sqlErrorType = ex.GetType().Name;
                var sqlEx = ex as SqlException;
                if (sqlEx != null) sqlErrorNumber = sqlEx.Number.ToString();
                sqlClassification = ClassifySql(ex);
            }

            bool openAiOk = false;
            string openAiError = "";
            try
            {
                string reply = new OpenAIClient().Chat("You are a backend health check.", "Reply only OK.");
                openAiOk = !string.IsNullOrWhiteSpace(reply);
            }
            catch (Exception ex)
            {
                openAiError = Safe(ex.Message);
            }

            var output = new StringBuilder();
            output.AppendLine("HEALTH_PAGE_OK=true");
            output.AppendLine("SQL_OK=" + sqlOk.ToString().ToLowerInvariant());
            output.AppendLine("SQL_TABLE_COUNT=" + (tableCount < 0 ? "" : tableCount.ToString()));
            output.AppendLine("SQL_ERROR_TYPE=" + sqlErrorType);
            output.AppendLine("SQL_ERROR_NUMBER=" + sqlErrorNumber);
            output.AppendLine("SQL_ERROR_CLASSIFICATION=" + sqlClassification);
            output.AppendLine("OPENAI_OK=" + openAiOk.ToString().ToLowerInvariant());
            output.AppendLine("OPENAI_ERROR=" + openAiError);

            Response.StatusCode = 200;
            Response.Write(output.ToString());
            Context.ApplicationInstance.CompleteRequest();
            return true;
        }

        private static string ClassifySql(Exception ex)
        {
            var sqlEx = ex as SqlException;
            if (sqlEx == null) return ex == null ? "UNKNOWN" : ex.GetType().Name.ToUpperInvariant();
            switch (sqlEx.Number)
            {
                case -2: return "CONNECT_TIMEOUT";
                case 18456: return "AUTHENTICATION_FAILED";
                case 4060: return "DATABASE_ACCESS_FAILED";
                case 53: return "NETWORK_OR_DNS";
                case 10060: return "NETWORK_TIMEOUT";
                case 11001: return "DNS_LOOKUP_FAILED";
                default: return "SQL_ERROR_" + sqlEx.Number;
            }
        }

        private static string Safe(string value)
        {
            if (string.IsNullOrEmpty(value)) return "";
            value = value.Replace("\r", " ").Replace("\n", " ").Trim();
            return value.Length > 500 ? value.Substring(0, 500) : value;
        }

        protected void btnEntra_Click(object sender, EventArgs e)
        {
            try
            {
                Response.Redirect(AuthService.BuildEntraAuthorizationUrl(Request), false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (Exception ex)
            {
                lblMessage.Text = HttpUtility.HtmlEncode(ex.Message);
                lblMessage.Visible = true;
            }
        }
    }
}
