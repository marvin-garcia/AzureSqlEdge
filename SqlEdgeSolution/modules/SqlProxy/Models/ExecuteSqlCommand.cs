using System;
using Newtonsoft.Json;

namespace SqlProxy.Models
{
    public class ExecuteSqlCommand
    {
        [JsonProperty("dataSource")]
        public string DataSource { get; set; }
        [JsonProperty("database")]
        public string Database { get; set; }
        [JsonProperty("table")]
        public string Table { get; set; }
        [JsonProperty("userId")]
        public string UserId { get; set; }
        [JsonProperty("password")]
        public string Password { get; set; }
        [JsonProperty("command")]
        public string Command { get; set; }
    }
}