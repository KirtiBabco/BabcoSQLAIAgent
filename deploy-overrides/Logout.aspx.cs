using System;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class Logout : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            string logoutUrl = AuthService.BuildEntraLogoutUrl(Request);
            AuthService.SignOut();
            Response.Redirect(logoutUrl, false);
            Context.ApplicationInstance.CompleteRequest();
        }
    }
}
