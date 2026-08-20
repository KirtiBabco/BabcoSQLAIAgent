using System;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class AuthComplete : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (AuthService.BootstrapEasyAuthSession(Request))
            {
                Response.Redirect("~/Default.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
                return;
            }

            Response.Redirect("~/Login.aspx?error=entra_session_missing", false);
            Context.ApplicationInstance.CompleteRequest();
        }
    }
}
