using System;
using System.Web.UI;

namespace SQL_AI_Agent
{
    public partial class Login : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            litConfigStatus.Text = "<strong>Mode:</strong> Temporary STD testing login &nbsp; | &nbsp; <strong>Role:</strong> Admin";

            if (!IsPostBack)
            {
                StartTestSessionAndContinue();
            }
        }

        protected void btnTestLogin_Click(object sender, EventArgs e)
        {
            StartTestSessionAndContinue();
        }

        // Kept temporarily so Login.aspx.cs can be deployed before the markup without breaking the live page.
        protected void btnEntra_Click(object sender, EventArgs e)
        {
            StartTestSessionAndContinue();
        }

        private void StartTestSessionAndContinue()
        {
            AuthService.StartTemporaryAdminSession();
            Response.Redirect("~/Default.aspx", false);
            Context.ApplicationInstance.CompleteRequest();
        }
    }
}
