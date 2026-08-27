<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="SQL_AI_Agent" %>
<script runat="server">
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
</script>
<!DOCTYPE html>
<html>
<head><meta charset="utf-8" /><title>Signing in...</title></head>
<body><p>Completing Microsoft sign-in...</p></body>
</html>
