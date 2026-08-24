using System;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class Admin : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!AuthService.IsSignedIn)
            {
                Response.Redirect("~/Login.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
                return;
            }

            if (!AuthService.IsAdmin)
            {
                Response.StatusCode = 403;
                Response.TrySkipIisCustomErrors = true;
                Response.Write("Admin access is required.");
                Context.ApplicationInstance.CompleteRequest();
                return;
            }
        }

        public string UserEmail { get { return AuthService.CurrentUserEmail; } }
        public string UserName { get { return AuthService.CurrentUserName; } }
        public string AuthProvider { get { return AuthService.GetEntraConfigurationStatus(); } }
        public string OpenAIModel { get { return AppConfig.OpenAIModel; } }
        public string OpenAIKeyStatus { get { return AppConfig.GetOpenAIApiKeyInfo().IsPresent ? "Configured" : "Not configured"; } }
        public string SqlSettingStatus { get { return string.IsNullOrWhiteSpace(AppConfig.SqlConnectionString) ? "Not configured" : "Configured"; } }
        public string InputPrice { get { return PriceText(AppConfig.OpenAIInputPricePer1M); } }
        public string CachedInputPrice { get { return PriceText(AppConfig.OpenAICachedInputPricePer1M); } }
        public string OutputPrice { get { return PriceText(AppConfig.OpenAIOutputPricePer1M); } }

        private static string PriceText(decimal value)
        {
            return value < 0m ? "Not configured" : "$" + value.ToString("0.######") + " / 1M tokens";
        }
    }
}
