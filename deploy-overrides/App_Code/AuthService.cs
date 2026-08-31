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
                return HttpContext.Current != null &&
                       HttpContext.Current.Session != null &&
                       !string.IsNullOrWhiteSpace(Convert.ToString(HttpContext.Current.Session["UserID"]));
            }
        }

        public static string CurrentUserId { get { return GetSession("UserID"); } }
        public static string CurrentUserName { get { return GetSession("UserName"); } }
        public static string CurrentUserEmail { get { return GetSession("UserEmail"); } }
        public static bool IsAdmin { get { return string.Equals(GetSession("UserRole"), "Admin", StringComparison.OrdinalIgnoreCase); } }
        public static bool IsEntraConfigured { get { return false; } }

        public static string GetEntraConfigurationStatus()
        {
            return "Temporarily disabled - STD testing login active";
        }

        public static void StartTemporaryAdminSession()
        {
            if (HttpContext.Current == null || HttpContext.Current.Session == null)
                throw new InvalidOperationException("ASP.NET session is unavailable.");

            HttpContext.Current.Session["UserID"] = "STD-TEST-ADMIN";
            HttpContext.Current.Session["UserName"] = "Test Admin";
            HttpContext.Current.Session["FullName"] = "Test Admin";
            HttpContext.Current.Session["UserEmail"] = "test-admin@local";
            HttpContext.Current.Session["UserRole"] = "Admin";
            HttpContext.Current.Session["UserType"] = "TemporaryTest";
            HttpContext.Current.Session["LoginDate"] = DateTime.UtcNow;
        }

        public static string BuildEntraAuthorizationUrl(HttpRequest request)
        {
            return VirtualPathUtility.ToAbsolute("~/Login.aspx");
        }

        public static string BuildEntraLogoutUrl(HttpRequest request)
        {
            return VirtualPathUtility.ToAbsolute("~/Login.aspx");
        }

        public static bool BootstrapEasyAuthSession(HttpRequest request)
        {
            return IsSignedIn;
        }

        public static void RequireLogin(HttpResponse response)
        {
            if (IsSignedIn) return;
            response.Redirect(VirtualPathUtility.ToAbsolute("~/Login.aspx"), false);
            HttpContext.Current.ApplicationInstance.CompleteRequest();
        }

        public static void RequireAdmin(HttpResponse response)
        {
            if (!IsSignedIn)
            {
                RequireLogin(response);
                return;
            }
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
            return HttpContext.Current == null || HttpContext.Current.Session == null
                ? ""
                : Convert.ToString(HttpContext.Current.Session[key]);
        }
    }
}
