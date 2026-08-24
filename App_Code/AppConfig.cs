using System;
using System.Configuration;
using System.Text.RegularExpressions;

namespace SQL_AI_Agent
{
    public static class AppConfig
    {
        public static string OpenAIUrl { get { return Get("OpenAIUrl", "https://api.openai.com/v1/responses"); } }

        public static string OpenAIApiKey
        {
            get
            {
                string key = GetEnvironment("OPENAI_API_KEY_DEVELOPMENT");
                if (string.IsNullOrWhiteSpace(key))
                    key = GetEnvironment("OPENAI_API_KEY");
                if (string.IsNullOrWhiteSpace(key))
                    throw new Exception("OPENAI_API_KEY_DEVELOPMENT (or OPENAI_API_KEY) is missing from server-side configuration.");
                return key.Trim();
            }
        }

        public static string OpenAIModel
        {
            get
            {
                string model = GetEnvironment("OPENAI_MODEL");
                return string.IsNullOrWhiteSpace(model) ? Get("OpenAIModel", "gpt-5-mini") : model.Trim();
            }
        }

        public static string SqlConnectionString
        {
            get
            {
                string value = GetEnvironment("BAP_SUPPORT_CONNECTION_STRING");
                if (string.IsNullOrWhiteSpace(value))
                    value = Get("SqlConnectionString", "");
                return NormalizeSqlConnectionString(value);
            }
        }

        public static int MaxRows { get { int v; return int.TryParse(Get("MaxRows", "200"), out v) ? v : 200; } }
        public static int CommandTimeoutSeconds { get { int v; return int.TryParse(Get("CommandTimeoutSeconds", "30"), out v) ? v : 30; } }

        private static string NormalizeSqlConnectionString(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "";
            value = Regex.Replace(value, @"(?i)\bConnectTimeout\s*=", "Connect Timeout=");
            value = Regex.Replace(value, @"(?i)\bConnectionTimeout\s*=", "Connection Timeout=");
            return value.Trim();
        }

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
