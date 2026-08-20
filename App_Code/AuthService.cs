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
                HttpContext context = HttpContext.Current;
                return context != null && context.Session != null && context.Session["UserID"] != null;
            }
        }

        public static bool IsEntraConfigured { get { return true; } }

        public static bool CanUseLocalTestLogin(HttpRequest request)
        {
            return request != null && request.IsLocal;
        }

        public static string GetResolvedRedirectUri(HttpRequest request)
        {
            if (request == null || request.Url == null) return "/AuthComplete.aspx";
            return request.Url.GetLeftPart(UriPartial.Authority) + VirtualPathUtility.ToAbsolute("~/AuthComplete.aspx");
        }

        public static string GetEntraConfigurationStatus()
        {
            return "Microsoft sign-in uses Azure App Service Authentication (Easy Auth).";
        }

        public static string BuildEntraAuthorizationUrl(HttpRequest request)
        {
            string returnUrl = VirtualPathUtility.ToAbsolute("~/AuthComplete.aspx");
            return VirtualPathUtility.ToAbsolute("~/.auth/login/aad") + "?post_login_redirect_uri=" + HttpUtility.UrlEncode(returnUrl);
        }

        public static void CompleteEntraLogin(HttpRequest request, string code, string state)
        {
            BootstrapEasyAuthSession(request);
        }

        public static bool BootstrapEasyAuthSession(HttpRequest request)
        {
            if (request == null || HttpContext.Current == null || HttpContext.Current.Session == null)
                return false;

            string email = FirstNonEmpty(
                request.Headers["X-MS-CLIENT-PRINCIPAL-NAME"],
                request.Headers["X-MS-TOKEN-AAD-PREFERRED-USERNAME"],
                request.Headers["X-MS-TOKEN-AAD-EMAIL"]);

            string principalId = request.Headers["X-MS-CLIENT-PRINCIPAL-ID"];
            if (string.IsNullOrWhiteSpace(email) && string.IsNullOrWhiteSpace(principalId))
                return false;

            HttpSessionStateBase session = new HttpSessionStateWrapper(HttpContext.Current.Session);
            session["UserID"] = string.IsNullOrWhiteSpace(principalId) ? email : principalId;
            session["UserName"] = string.IsNullOrWhiteSpace(email) ? "Microsoft User" : email;
            session["FullName"] = session["UserName"];
            session["UserEmail"] = email ?? "";
            session["UserRole"] = "User";
            session["UserType"] = "Entra";
            session["LoginDate"] = DateTime.UtcNow.ToString("o");
            return true;
        }

        public static void LocalTestAdminLogin(HttpRequest request)
        {
            if (!CanUseLocalTestLogin(request))
                throw new Exception("Local test login is available only on localhost.");

            HttpContext.Current.Session["UserID"] = "LOCAL-ADMIN";
            HttpContext.Current.Session["UserName"] = "Local Test Admin";
            HttpContext.Current.Session["FullName"] = "Local Test Admin";
            HttpContext.Current.Session["UserEmail"] = "local.admin@localhost";
            HttpContext.Current.Session["UserRole"] = "Admin";
            HttpContext.Current.Session["UserType"] = "LocalTest";
            HttpContext.Current.Session["LoginDate"] = DateTime.UtcNow.ToString("o");
        }

        private static string FirstNonEmpty(params string[] values)
        {
            foreach (string value in values)
                if (!string.IsNullOrWhiteSpace(value)) return value;
            return null;
        }
    }
}
