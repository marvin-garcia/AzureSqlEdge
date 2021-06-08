using System;
using System.Threading.Tasks;
using System.Data.SqlClient;

namespace SqlProxy.Methods
{
    public class SqlHelper
    {
        public static string GenerateConnectionString(string dataSource, string database, string userId, string password, int timeout = 30, bool trustServerCertificate = true, bool encrypt = true)
        {
            string connectionString = $"Data Source={dataSource};Initial Catalog={database};User ID={userId};Password={password};Connect Timeout={timeout};TrustServerCertificate={trustServerCertificate};Encrypt={encrypt}";
            return connectionString;
        }

        public static async Task<string> ExecuteCommand(string connectionString, string queryString)
        {
            string response = string.Empty;

            using (SqlConnection connection = new SqlConnection(connectionString))
            {
                SqlCommand command = new SqlCommand(queryString, connection);
                connection.Open();
                using (SqlDataReader reader = await command.ExecuteReaderAsync())
                {
                    if (reader.Read())
                    {
                        response = reader.ToString();
                    }
                }
            }

            return response;
        }
    }
}