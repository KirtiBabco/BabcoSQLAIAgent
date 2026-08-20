using System;
using System.Configuration;

namespace SQL_AI_Agent
{
    public static class AppConfig
    {
        public static string OpenAIUrl { get { return Get("OpenAIUrl", "https://api.openai.com/v1/responses"); } }

        public static string OpenAIApiKey
        {
            get
            {
                string key = GetEnvironment("OPENAI_API_KEY");
                if (string.IsNullOrWhiteSpace(key))
                    throw new Exception("OPENAI_API_KEY is missing from server-side configuration.");
                return key.Trim();
            }
        }

        public static string OpenAIModel { get { return GetEnvironment("OPENAI_MODEL", Get("OpenAIModel", "gpt-5-mini")); } }

        public static string SqlConnectionString
        {
            get
            {
                string value = GetEnvironment("BAP_SUPPORT_CONNECTION_STRING");
                if (string.IsNullOrWhiteSpace(value))
                    value = Get("SqlConnectionString", "");
                return value;
            }
        }

        public static int MaxRows { get { int v; return int.TryParse(Get("MaxRows", "200"), out v) ? v : 200; } }
        public static int CommandTimeoutSeconds { get { int v; return int.TryParse(Get("CommandTimeoutSeconds", "30"), out v) ? v : 30; } }

        public static string EntraClientId { get { return GetEnvironment("ENTRA_CLIENT_ID"); } }
        public static string EntraTenantId { get { return GetEnvironment("ENTRA_TENANT_ID"); } }
        public static string EntraClientSecret { get { return GetEnvironment("ENTRA_CLIENT_SECRET"); } }
        public static string GetEntraTenantSource() { return string.IsNullOrWhiteSpace(EntraTenantId) ? "missing" : "server setting"; }
        public static string GetEntraClientSource() { return string.IsNullOrWhiteSpace(EntraClientId) ? "missing" : "server setting"; }
        public static string GetEntraSecretSource() { return string.IsNullOrWhiteSpace(EntraClientSecret) ? "missing" : "server setting"; }

        private static string GetEnvironment(string key, string fallback = "")
        {
            string value = Environment.GetEnvironmentVariable(key, EnvironmentVariableTarget.Process);
            if (string.IsNullOrWhiteSpace(value)) value = Environment.GetEnvironmentVariable(key);
            return string.IsNullOrWhiteSpace(value) ? fallback : value;
        }

        private static string Get(string key, string fallback)
        {
            string value = ConfigurationManager.AppSettings[key];
            return string.IsNullOrWhiteSpace(value) ? fallback : value;
        }
    }
}
