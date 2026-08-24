using System;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.Text.RegularExpressions;

namespace SQL_AI_Agent
{
    public sealed class EnvironmentSecretInfo
    {
        public string Value { get; set; }
        public string Source { get; set; }
        public string Preview { get; set; }
        public bool IsPresent { get { return !string.IsNullOrWhiteSpace(Value); } }
    }

    public static class AppConfig
    {
        public const string OpenAIApiKeyVariable = "OPENAI_API_KEY_DEVELOPMENT";
        public const string SqlConnectionVariable = "BAP_SUPPORT_CONNECTION_STRING";

        public static string OpenAIUrl { get { return Get("OpenAIUrl", "https://api.openai.com/v1/responses"); } }

        public static string OpenAIApiKey
        {
            get
            {
                EnvironmentSecretInfo info = GetOpenAIApiKeyInfo();
                if (!info.IsPresent)
                    throw new Exception(OpenAIApiKeyVariable + " environment variable was not found. Configure it as an Azure App Service environment variable and restart the app.");
                if (info.Value.IndexOf(' ') >= 0)
                    throw new Exception(OpenAIApiKeyVariable + " contains a space. Store only the API key value, without 'Bearer ', variable-name text, or extra spaces.");
                if (!info.Value.StartsWith("sk-", StringComparison.Ordinal))
                    throw new Exception(OpenAIApiKeyVariable + " does not look like an OpenAI API Platform key. Expected a key beginning with 'sk-'.");
                return info.Value;
            }
        }

        public static EnvironmentSecretInfo GetOpenAIApiKeyInfo()
        {
            return GetEnvironmentSecretInfo(OpenAIApiKeyVariable);
        }

        public static string OpenAIModel
        {
            get
            {
                string model = GetEnvironmentOrConfig("OPENAI_MODEL", "OpenAIModel");
                return string.IsNullOrWhiteSpace(model) ? "gpt-5-mini" : model.Trim();
            }
        }

        public static bool OpenAIAllowModelFallback { get { return GetBool("OpenAIAllowModelFallback", true); } }
        public static string OpenAIModelFallbacks { get { return Get("OpenAIModelFallbacks", "gpt-5-mini,gpt-4o-mini"); } }
        public static int OpenAIModelCacheMinutes { get { return GetInt("OpenAIModelCacheMinutes", 5); } }
        public static int OpenAIQuotaCooldownMinutes { get { return GetInt("OpenAIQuotaCooldownMinutes", 15); } }

        public static List<string> GetOpenAIModelCandidates()
        {
            var result = new List<string>();
            AddUnique(result, OpenAIModel);
            if (OpenAIAllowModelFallback)
            {
                string[] fallbacks = (OpenAIModelFallbacks ?? "").Split(new[] { ',', ';', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (string fallback in fallbacks) AddUnique(result, fallback);
            }
            return result;
        }

        public static string SqlConnectionString
        {
            get
            {
                string value = GetEnvironmentSecretInfo(SqlConnectionVariable).Value;
                return NormalizeSqlConnectionString(value);
            }
        }

        public static int MaxRows { get { return GetInt("MaxRows", 200); } }
        public static int CommandTimeoutSeconds { get { return GetInt("CommandTimeoutSeconds", 30); } }
        public static string AdminEmails { get { return GetEnvironmentOrConfig("AI_SQL_AGENT_ADMIN_EMAILS", "AdminEmails"); } }

        public static decimal OpenAIInputPricePer1M { get { return GetDecimal("OpenAIInputPricePer1M", -1m); } }
        public static decimal OpenAICachedInputPricePer1M { get { return GetDecimal("OpenAICachedInputPricePer1M", -1m); } }
        public static decimal OpenAIOutputPricePer1M { get { return GetDecimal("OpenAIOutputPricePer1M", -1m); } }
        public static int TelemetryMaxRecords { get { return GetInt("TelemetryMaxRecords", 5000); } }
        public static bool TelemetryAutoCreateSchema { get { return GetBool("TelemetryAutoCreateSchema", true); } }

        private static void AddUnique(List<string> values, string value)
        {
            value = (value ?? "").Trim();
            if (value.Length == 0) return;
            foreach (string existing in values)
                if (string.Equals(existing, value, StringComparison.OrdinalIgnoreCase)) return;
            values.Add(value);
        }

        private static EnvironmentSecretInfo GetEnvironmentSecretInfo(string name)
        {
            string value = SafeGetEnvironmentVariable(name, EnvironmentVariableTarget.Process);
            string source = "Process";
            if (string.IsNullOrWhiteSpace(value)) { value = SafeGetEnvironmentVariable(name, EnvironmentVariableTarget.User); source = "User"; }
            if (string.IsNullOrWhiteSpace(value)) { value = SafeGetEnvironmentVariable(name, EnvironmentVariableTarget.Machine); source = "Machine"; }
            if (string.IsNullOrWhiteSpace(value)) source = "Not found";
            value = NormalizeSecretValue(name, value);
            return new EnvironmentSecretInfo { Value = value, Source = source, Preview = MaskSecret(value) };
        }

        private static string SafeGetEnvironmentVariable(string name, EnvironmentVariableTarget target)
        {
            try { return Environment.GetEnvironmentVariable(name, target); }
            catch { return ""; }
        }

        private static string NormalizeSecretValue(string name, string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "";
            value = value.Trim();
            string assignmentPrefix = name + "=";
            if (value.StartsWith(assignmentPrefix, StringComparison.OrdinalIgnoreCase)) value = value.Substring(assignmentPrefix.Length).Trim();
            if (value.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)) value = value.Substring(7).Trim();
            if (value.Length >= 2 && ((value[0] == '"' && value[value.Length - 1] == '"') || (value[0] == '\'' && value[value.Length - 1] == '\''))) value = value.Substring(1, value.Length - 2).Trim();
            return value.Replace("\r", "").Replace("\n", "").Replace("\t", "").Trim();
        }

        private static string NormalizeSqlConnectionString(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "";

            // Azure/other tooling sometimes emits ConnectTimeout without a space.
            // System.Data.SqlClient (.NET Framework) requires Connect Timeout / Connection Timeout.
            value = Regex.Replace(value, @"(?i)(^|;)\s*ConnectTimeout\s*=", "$1Connect Timeout=");
            value = Regex.Replace(value, @"(?i)(^|;)\s*ConnectionTimeout\s*=", "$1Connection Timeout=");
            return value.Trim();
        }

        private static string MaskSecret(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "(not found)";
            if (value.Length <= 10) return value.Substring(0, Math.Min(3, value.Length)) + "...";
            int prefixLength = Math.Min(10, value.Length - 4);
            return value.Substring(0, prefixLength) + "..." + value.Substring(value.Length - 4);
        }

        private static string GetEnvironmentOrConfig(string environmentName, string configKey)
        {
            EnvironmentSecretInfo info = GetEnvironmentSecretInfo(environmentName);
            if (info.IsPresent) return info.Value;
            return Get(configKey, "");
        }

        private static string Get(string key, string fallback)
        {
            string value = ConfigurationManager.AppSettings[key];
            return string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
        }

        private static int GetInt(string key, int fallback)
        {
            int value;
            return int.TryParse(Get(key, fallback.ToString(CultureInfo.InvariantCulture)), out value) ? value : fallback;
        }

        private static bool GetBool(string key, bool fallback)
        {
            bool value;
            return bool.TryParse(Get(key, fallback.ToString()), out value) ? value : fallback;
        }

        private static decimal GetDecimal(string key, decimal fallback)
        {
            decimal value;
            return decimal.TryParse(Get(key, fallback.ToString(CultureInfo.InvariantCulture)), NumberStyles.Any, CultureInfo.InvariantCulture, out value) ? value : fallback;
        }
    }
}
