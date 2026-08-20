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
            string redirectUri = AuthService.GetResolvedRedirectUri(Request);
            if (AuthService.IsEntraConfigured)
            {
                litConfigStatus.Text = "<strong>Entra:</strong> Ready"
                    + "<br/><span class=\"configLine\">Tenant: " + HttpUtility.HtmlEncode(AppConfig.GetEntraTenantSource())
                    + " &nbsp; | &nbsp; Client: " + HttpUtility.HtmlEncode(AppConfig.GetEntraClientSource())
                    + " &nbsp; | &nbsp; Secret: " + HttpUtility.HtmlEncode(AppConfig.GetEntraSecretSource()) + "</span>"
                    + "<br/><span class=\"configLine\">Redirect URI: " + HttpUtility.HtmlEncode(redirectUri) + "</span>";
            }
            else
            {
                litConfigStatus.Text = "<strong>Entra setup required.</strong> " + HttpUtility.HtmlEncode(AuthService.GetEntraConfigurationStatus())
                    + "<br/><span class=\"configLine\">Expected redirect URI: " + HttpUtility.HtmlEncode(redirectUri) + "</span>";
            }

            if (!string.IsNullOrWhiteSpace(Request.QueryString["error"]))
            {
                ShowMessage("Microsoft Entra returned: " + Request.QueryString["error"] + "\n" + Request.QueryString["error_description"]);
                return;
            }

            string code = Request.QueryString["code"];
            string state = Request.QueryString["state"];
            if (!string.IsNullOrWhiteSpace(code))
            {
                try
                {
                    AuthService.CompleteEntraLogin(Request, code, state);
                    Response.Redirect("~/Default.aspx", false);
                    Context.ApplicationInstance.CompleteRequest();
                }
                catch (Exception ex) { ShowMessage(ex.Message); }
                return;
            }

            if (!IsPostBack && AuthService.IsSignedIn)
            {
                Response.Redirect("~/Default.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
        }

        protected void btnEntra_Click(object sender, EventArgs e)
        {
            try
            {
                string url = AuthService.BuildEntraAuthorizationUrl(Request);
                Response.Redirect(url, false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (Exception ex) { ShowMessage(ex.Message); }
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
            catch (Exception ex) { ShowMessage(ex.Message); }
        }

        protected void btnLocalTest_Click(object sender, EventArgs e)
        {
            try
            {
                AuthService.LocalTestAdminLogin(Request);
                Response.Redirect("~/Default.aspx", false);
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (Exception ex) { ShowMessage(ex.Message); }
        }

        private void ShowMessage(string message)
        {
            lblMessage.Text = HttpUtility.HtmlEncode(message ?? "Login failed.");
            lblMessage.Visible = true;
        }
    }
}