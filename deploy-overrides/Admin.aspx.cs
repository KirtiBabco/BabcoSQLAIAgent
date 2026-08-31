using System;
using System.Configuration;
using System.Globalization;
using System.Web;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class Admin : Page
    {
        public string UserEmail { get; private set; }
        public string UserName { get; private set; }
        public string AuthProvider { get { return "Azure App Service Easy Auth / Microsoft Entra ID"; } }
        public string OpenAIModel { get; private set; }
        public string OpenAIKeyStatus { get; private set; }
        public string SqlSettingStatus { get; private set; }
        public string InputPrice { get; private set; }
        public string CachedInputPrice { get; private set; }
        public string OutputPrice { get; private set; }

        protected void Page_Load(object sender, EventArgs e)
        {
            UserEmail = FirstNonEmpty(Request.Headers["X-MS-CLIENT-PRINCIPAL-NAME"], Request.Headers["X-MS-CLIENT-PRINCIPAL-ID"]);
            if (string.IsNullOrWhiteSpace(UserEmail))
            {
                Response.Redirect("~/Login.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
                return;
            }

            if (!IsAdminEmail(UserEmail))
            {
                Response.StatusCode = 403;
                Response.TrySkipIisCustomErrors = true;
                Response.Write("Admin access is required.");
                Context.ApplicationInstance.CompleteRequest();
                return;
            }

            UserName = ToDisplayName(UserEmail);
            OpenAIModel = FirstNonEmpty(Environment.GetEnvironmentVariable("OPENAI_MODEL"), ConfigurationManager.AppSettings["OpenAIModel"], "gpt-5-mini");
            OpenAIKeyStatus = HasValue("OPENAI_API_KEY_DEVELOPMENT", "OPENAI_API_KEY") ? "Configured" : "Not configured";
            SqlSettingStatus = HasSqlSetting() ? "Configured" : "Not configured";
            InputPrice = PriceText(ReadDecimalSetting("OpenAIInputPricePer1M", "OPENAI_INPUT_PRICE_PER_1M"));
            CachedInputPrice = PriceText(ReadDecimalSetting("OpenAICachedInputPricePer1M", "OPENAI_CACHED_INPUT_PRICE_PER_1M"));
            OutputPrice = PriceText(ReadDecimalSetting("OpenAIOutputPricePer1M", "OPENAI_OUTPUT_PRICE_PER_1M"));
        }

        private static bool IsAdminEmail(string email)
        {
            if (string.Equals((email ?? "").Trim(), "kirti@babcofoods.com", StringComparison.OrdinalIgnoreCase)) return true;

            string configured = FirstNonEmpty(
                Environment.GetEnvironmentVariable("AI_SQL_AGENT_ADMIN_EMAILS"),
                ConfigurationManager.AppSettings["AdminEmails"]);
            if (string.IsNullOrWhiteSpace(configured)) return false;

            string[] values = configured.Split(new[] { ',', ';', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string value in values)
                if (string.Equals(value.Trim(), email.Trim(), StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        private static bool HasSqlSetting()
        {
            if (HasValue(
                "SQLCONNSTR_BabcoSupportConnectionString",
                "SQLAZURECONNSTR_BabcoSupportConnectionString",
                "CUSTOMCONNSTR_BabcoSupportConnectionString",
                "BAP_SUPPORT_CONNECTION_STRING",
                "SQL_BAP_SUPPORT_CONNECTION_STRING",
                "SQL_CONNECTION_STRING")) return true;

            ConnectionStringSettings c = ConfigurationManager.ConnectionStrings["BabcoSupportConnectionString"];
            if (c != null && !string.IsNullOrWhiteSpace(c.ConnectionString)) return true;
            return !string.IsNullOrWhiteSpace(ConfigurationManager.AppSettings["SqlConnectionString"]);
        }

        private static bool HasValue(params string[] names)
        {
            foreach (string name in names)
                if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(name))) return true;
            return false;
        }

        private static decimal ReadDecimalSetting(string appSettingKey, string environmentKey)
        {
            string raw = FirstNonEmpty(Environment.GetEnvironmentVariable(environmentKey), ConfigurationManager.AppSettings[appSettingKey]);
            decimal value;
            return decimal.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out value) ? value : -1m;
        }

        private static string PriceText(decimal value)
        {
            return value < 0m ? "Not configured" : "$" + value.ToString("0.######", CultureInfo.InvariantCulture) + " / 1M tokens";
        }

        private static string ToDisplayName(string email)
        {
            string value = (email ?? "").Trim();
            int at = value.IndexOf('@');
            if (at > 0) value = value.Substring(0, at);
            return string.IsNullOrWhiteSpace(value) ? "Admin" : value;
        }

        private static string FirstNonEmpty(params string[] values)
        {
            foreach (string value in values)
                if (!string.IsNullOrWhiteSpace(value)) return value.Trim();
            return "";
        }
    }
}
