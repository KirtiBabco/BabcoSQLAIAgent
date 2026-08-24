using System;
using System.Web;

namespace SQL_AI_Agent
{
    public static class AuthService
    {
        public static bool IsSignedIn
        {
            get
            {
                BootstrapEasyAuthSession(HttpContext.Current == null ? null : HttpContext.Current.Request);
                return HttpContext.Current != null && HttpContext.Current.Session != null && !string.IsNullOrWhiteSpace(Convert.ToString(HttpContext.Current.Session["UserID"]));
            }
        }

        public static string CurrentUserId { get { return GetSession("UserID"); } }
        public static string CurrentUserName { get { return GetSession("UserName"); } }
        public static string CurrentUserEmail { get { return GetSession("UserEmail"); } }
        public static bool IsAdmin { get { return string.Equals(GetSession("UserRole"), "Admin", StringComparison.OrdinalIgnoreCase); } }
        public static bool IsEntraConfigured { get { return true; } }

        public static string GetEntraConfigurationStatus()
        {
            return "Azure App Service Easy Auth / Microsoft Entra ID";
        }

        public static string BuildEntraAuthorizationUrl(HttpRequest request)
        {
            string callback = VirtualPathUtility.ToAbsolute("~/AuthComplete.aspx");
            return "/.auth/login/aad?post_login_redirect_uri=" + HttpUtility.UrlEncode(callback);
        }

        public static string BuildEntraLogoutUrl(HttpRequest request)
        {
            string login = VirtualPathUtility.ToAbsolute("~/Login.aspx");
            return "/.auth/logout?post_logout_redirect_uri=" + HttpUtility.UrlEncode(login);
        }

        public static bool BootstrapEasyAuthSession(HttpRequest request)
        {
            if (request == null || HttpContext.Current == null || HttpContext.Current.Session == null) return false;
            if (!string.IsNullOrWhiteSpace(Convert.ToString(HttpContext.Current.Session["UserID"]))) return true;

            string email = FirstNonEmpty(
                request.Headers["X-MS-CLIENT-PRINCIPAL-NAME"],
                request.Headers["X-MS-CLIENT-PRINCIPAL-ID"]);
            string id = FirstNonEmpty(request.Headers["X-MS-CLIENT-PRINCIPAL-ID"], email);
            if (string.IsNullOrWhiteSpace(id)) return false;

            string displayName = email;
            if (!string.IsNullOrWhiteSpace(email) && email.IndexOf('@') > 0)
                displayName = email.Substring(0, email.IndexOf('@'));

            HttpContext.Current.Session["UserID"] = id;
            HttpContext.Current.Session["UserName"] = displayName;
            HttpContext.Current.Session["FullName"] = displayName;
            HttpContext.Current.Session["UserEmail"] = email;
            HttpContext.Current.Session["UserRole"] = IsAdminEmail(email) ? "Admin" : "User";
            HttpContext.Current.Session["UserType"] = "EntraID";
            HttpContext.Current.Session["LoginDate"] = DateTime.UtcNow;
            return true;
        }

        public static void RequireLogin(HttpResponse response)
        {
            if (IsSignedIn) return;
            response.Redirect(VirtualPathUtility.ToAbsolute("~/Login.aspx"), false);
            HttpContext.Current.ApplicationInstance.CompleteRequest();
        }

        public static void RequireAdmin(HttpResponse response)
        {
            RequireLogin(response);
            if (IsAdmin) return;
            response.StatusCode = 403;
            response.TrySkipIisCustomErrors = true;
            response.Write("Admin access is required.");
            HttpContext.Current.ApplicationInstance.CompleteRequest();
        }

        public static void SignOut()
        {
            if (HttpContext.Current == null || HttpContext.Current.Session == null) return;
            HttpContext.Current.Session.Clear();
            HttpContext.Current.Session.Abandon();
        }

        private static string GetSession(string key)
        {
            BootstrapEasyAuthSession(HttpContext.Current == null ? null : HttpContext.Current.Request);
            return HttpContext.Current == null || HttpContext.Current.Session == null ? "" : Convert.ToString(HttpContext.Current.Session[key]);
        }

        private static bool IsAdminEmail(string email)
        {
            if (string.IsNullOrWhiteSpace(email)) return false;

            // Permanent owner/admin login.
            if (string.Equals(email.Trim(), "kirti@babcofoods.com", StringComparison.OrdinalIgnoreCase))
                return true;

            if (string.IsNullOrWhiteSpace(AppConfig.AdminEmails)) return false;
            string[] values = AppConfig.AdminEmails.Split(new[] { ',', ';', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string value in values)
                if (string.Equals(value.Trim(), email.Trim(), StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        private static string FirstNonEmpty(params string[] values)
        {
            foreach (string value in values)
                if (!string.IsNullOrWhiteSpace(value)) return value.Trim();
            return "";
        }
    }
}
