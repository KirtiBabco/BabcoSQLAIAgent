using System;
using System.Text.RegularExpressions;

namespace SQL_AI_Agent
{
    public sealed class AgentService
    {
        private readonly OpenAIClient _llm = new OpenAIClient();
        private readonly SqlTool _sql = new SqlTool();

        public string Ask(string userQuestion)
        {
            string schema = _sql.GetSchema();
            string sql = _llm.Chat(BuildSqlPrompt(schema), userQuestion);
            sql = ExtractSql(sql);
            string data = _sql.ExecuteReadOnly(sql);
            return _llm.Chat(BuildAnswerPrompt(sql, data), userQuestion);
        }

        private static string BuildSqlPrompt(string schema)
        {
            return @"You are the SQL planner inside a business AI Agent.
Understand the user's question in any language.
Use ONLY the database schema below.
Generate ONE Microsoft SQL Server SELECT query.
Never INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, EXEC or modify data.
Never invent a table or column.
Return ONLY SQL, without markdown or explanation.
For large lists prefer TOP 200.

DATABASE SCHEMA:
" + schema;
        }

        private static string BuildAnswerPrompt(string sql, string data)
        {
            return @"You are the answer layer of a business AI Agent.
Answer the user's original question using ONLY the SQL result below.
Do not invent facts. Be concise and clear. Reply in the user's language where practical.
Do not show SQL unless the user asks. If there are no matching rows, say so.

SQL:
" + sql + @"

RESULT:
" + data;
        }

        private static string ExtractSql(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) throw new Exception("OpenAI returned an empty SQL response.");
            Match match = Regex.Match(text, @"```(?:sql)?\s*(.*?)```", RegexOptions.IgnoreCase | RegexOptions.Singleline);
            if (match.Success) return match.Groups[1].Value.Trim();
            int index = text.IndexOf("SELECT", StringComparison.OrdinalIgnoreCase);
            return index >= 0 ? text.Substring(index).Trim() : text.Trim();
        }
    }
}
