using System;
using System.Web;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class Login : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            litConfigStatus.Text = "<strong>Entra:</strong> Azure App Service Easy Auth &nbsp; | &nbsp; <strong>Admin list:</strong> " +
                (string.IsNullOrWhiteSpace(AppConfig.AdminEmails) ? "Not set (all Entra users are standard users)" : "Configured");

            if (!IsPostBack && AuthService.BootstrapEasyAuthSession(Request))
            {
                Response.Redirect("~/Default.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
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
