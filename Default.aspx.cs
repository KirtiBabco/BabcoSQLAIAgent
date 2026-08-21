using System;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class Default : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!AuthService.IsSignedIn)
                AuthService.BootstrapEasyAuthSession(Request);

            if (!AuthService.IsSignedIn)
            {
                Response.Redirect("~/Login.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
        }

        [System.Web.Services.WebMethod(EnableSession = true)]
        [System.Web.Script.Services.ScriptMethod(ResponseFormat = System.Web.Script.Services.ResponseFormat.Json)]
        public static string AskAgent(string prompt)
        {
            if (!AuthService.IsSignedIn)
                throw new Exception("Authentication required.");
            if (string.IsNullOrWhiteSpace(prompt))
                throw new Exception("Please enter a question.");
            return new AgentService().Ask(prompt.Trim());
        }
    }
}
