using System;
using System.Web;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class Login : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            pnlLocalTest.Visible = AuthService.CanUseLocalTestLogin(Request);
            btnEntra.Enabled = true;

            litConfigStatus.Text =
                "<strong>Microsoft Entra:</strong> Azure App Service Easy Auth"
                + "<br/><span class=\"configLine\">No ENTRA_CLIENT_ID, ENTRA_CLIENT_SECRET or page-level OAuth configuration is required by this application.</span>"
                + "<br/><span class=\"configLine\">Sign-in endpoint: /.auth/login/aad</span>";

            if (!string.IsNullOrWhiteSpace(Request.QueryString["error"]))
            {
                ShowMessage("Microsoft sign-in could not be completed. " + Request.QueryString["error"]);
                return;
            }

            if (!IsPostBack)
            {
                if (!AuthService.IsSignedIn)
                    AuthService.BootstrapEasyAuthSession(Request);

                if (AuthService.IsSignedIn)
                {
                    Response.Redirect("~/Default.aspx", false);
                    Context.ApplicationInstance.CompleteRequest();
                }
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
                ShowMessage(ex.Message);
            }
        }

        protected void btnTemporary_Click(object sender, EventArgs e)
        {
            try
            {
                Session["UserID"] = "TEMP-USER";
                Session["UserName"] = "Temporary User";
                Session["FullName"] = "Temporary User";
                Session["UserEmail"] = "temporary.user@babcofoods.com";
                Session["UserRole"] = "User";
                Session["UserType"] = "Temporary";
                Session["LoginDate"] = DateTime.UtcNow.ToString("o");
                Response.Redirect("~/Default.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (Exception ex)
            {
                ShowMessage(ex.Message);
            }
        }

        protected void btnLocalTest_Click(object sender, EventArgs e)
        {
            try
            {
                AuthService.LocalTestAdminLogin(Request);
                Response.Redirect("~/Default.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (Exception ex)
            {
                ShowMessage(ex.Message);
            }
        }

        private void ShowMessage(string message)
        {
            lblMessage.Text = HttpUtility.HtmlEncode(message ?? "Login failed.");
            lblMessage.Visible = true;
        }
    }
}
