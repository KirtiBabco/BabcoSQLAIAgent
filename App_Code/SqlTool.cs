using System;
using System.Data.SqlClient;
using System.Text;
using System.Text.RegularExpressions;

namespace SQL_AI_Agent
{
    public sealed class SqlTool
    {
        public string GetSchema()
        {
            EnsureConfigured();
            var sb = new StringBuilder();
            using (var con = new SqlConnection(AppConfig.SqlConnectionString))
            using (var cmd = new SqlCommand(@"SELECT TABLE_SCHEMA,TABLE_NAME,COLUMN_NAME,DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS ORDER BY TABLE_SCHEMA,TABLE_NAME,ORDINAL_POSITION;", con))
            {
                cmd.CommandTimeout = AppConfig.CommandTimeoutSeconds;
                con.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    string lastTable = null;
                    while (rd.Read())
                    {
                        string table = rd.GetString(0) + "." + rd.GetString(1);
                        if (!string.Equals(lastTable, table, StringComparison.OrdinalIgnoreCase))
                        {
                            if (sb.Length > 0) sb.AppendLine();
                            sb.Append(table).Append(": ");
                            lastTable = table;
                        }
                        else sb.Append(", ");
                        sb.Append(rd.GetString(2)).Append(" ").Append(rd.GetString(3));
                    }
                }
            }
            if (sb.Length == 0) throw new Exception("SQL Server returned no table/column metadata.");
            return sb.ToString();
        }

        public string ExecuteReadOnly(string sql)
        {
            EnsureConfigured();
            sql = CleanSql(sql);
            ValidateReadOnlySql(sql);
            var sb = new StringBuilder();
            using (var con = new SqlConnection(AppConfig.SqlConnectionString))
            using (var cmd = new SqlCommand(sql, con))
            {
                cmd.CommandTimeout = AppConfig.CommandTimeoutSeconds;
                con.Open();
                using (var rd = cmd.ExecuteReader())
                {
                    for (int i = 0; i < rd.FieldCount; i++) { if (i > 0) sb.Append(" | "); sb.Append(rd.GetName(i)); }
                    sb.AppendLine();
                    int rows = 0;
                    while (rd.Read() && rows < AppConfig.MaxRows)
                    {
                        for (int i = 0; i < rd.FieldCount; i++) { if (i > 0) sb.Append(" | "); object v = rd.GetValue(i); sb.Append(v == DBNull.Value ? "" : Convert.ToString(v)); }
                        sb.AppendLine(); rows++;
                    }
                    sb.Append("Rows shown: ").Append(rows);
                }
            }
            return sb.ToString();
        }

        private static string CleanSql(string sql)
        {
            sql = (sql ?? "").Trim();
            sql = Regex.Replace(sql, @"^```sql\s*", "", RegexOptions.IgnoreCase);
            sql = Regex.Replace(sql, @"^```\s*", "", RegexOptions.IgnoreCase);
            sql = Regex.Replace(sql, @"\s*```$", "", RegexOptions.IgnoreCase);
            return sql.Trim().TrimEnd(';').Trim() + ";";
        }

        private static void ValidateReadOnlySql(string sql)
        {
            string n = " " + Regex.Replace(sql, @"\s+", " ").Trim().ToUpperInvariant() + " ";
            if (!n.TrimStart().StartsWith("SELECT ")) throw new Exception("Safety blocked the query. Only SELECT statements are allowed.");
            string[] blocked = { " INSERT "," UPDATE "," DELETE "," MERGE "," DROP "," ALTER "," CREATE "," TRUNCATE "," EXEC "," EXECUTE "," GRANT "," REVOKE "," DENY "," DBCC "," BACKUP "," RESTORE "," XP_"," SP_OA"," OPENROWSET"," OPENDATASOURCE" };
            foreach (string x in blocked) if (n.Contains(x)) throw new Exception("Safety blocked the query because it contains: " + x.Trim());
            if (n.Contains("--") || n.Contains("/*") || n.Contains("*/")) throw new Exception("Safety blocked SQL comments.");
            if (Regex.IsMatch(n, @"\bINTO\s+[A-Z0-9_\.\[\]]+")) throw new Exception("SELECT INTO is not allowed.");
        }

        private static void EnsureConfigured()
        {
            if (string.IsNullOrWhiteSpace(AppConfig.SqlConnectionString)) throw new Exception("BAP_SUPPORT_CONNECTION_STRING is missing from server-side configuration.");
        }
    }
}
