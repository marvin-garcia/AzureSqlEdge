namespace SqlProxy
{
    using System;
    using System.IO;
    using System.Runtime.InteropServices;
    using System.Runtime.Loader;
    using System.Security.Cryptography.X509Certificates;
    using System.Text;
    using System.Threading;
    using System.Threading.Tasks;
    using Microsoft.Azure.Devices.Client;
    using Microsoft.Azure.Devices.Client.Transport.Mqtt;
    using Microsoft.Extensions.Logging;
    using Newtonsoft.Json;
    using SqlProxy.Models;
    using SqlProxy.Methods;
    using IoTEdgeLogger;
    using Newtonsoft.Json.Linq;

    class Program
    {
        static int counter;
        static ILogger logger;

        static void Main(string[] args)
        {
            Logger.SetLogLevel("debug");
            logger = Logger.Factory.CreateLogger<string>();
            Init().Wait();

            // Wait until the app unloads or is cancelled
            var cts = new CancellationTokenSource();
            AssemblyLoadContext.Default.Unloading += (ctx) => cts.Cancel();
            Console.CancelKeyPress += (sender, cpe) => cts.Cancel();
            WhenCancelled(cts.Token).Wait();
        }

        /// <summary>
        /// Handles cleanup operations when app is cancelled or unloads
        /// </summary>
        public static Task WhenCancelled(CancellationToken cancellationToken)
        {
            var tcs = new TaskCompletionSource<bool>();
            cancellationToken.Register(s => ((TaskCompletionSource<bool>)s).SetResult(true), tcs);
            return tcs.Task;
        }

        /// <summary>
        /// Initializes the ModuleClient and sets up the callback to receive
        /// messages containing temperature information
        /// </summary>
        static async Task Init()
        {
            MqttTransportSettings mqttSetting = new MqttTransportSettings(TransportType.Mqtt_Tcp_Only);
            ITransportSettings[] settings = { mqttSetting };

            // Open a connection to the Edge runtime
            ModuleClient ioTHubModuleClient = await ModuleClient.CreateFromEnvironmentAsync(settings);
            await ioTHubModuleClient.OpenAsync();
            logger.LogInformation("IoT Hub module client initialized.");

            // Register callback to be called when a message is received by the module
            await ioTHubModuleClient.SetInputMessageHandlerAsync("input1", PipeMessage, ioTHubModuleClient);

            await ioTHubModuleClient.SetMethodHandlerAsync("ExecuteSqlCommand", ExecuteSqlCommandAsync, ioTHubModuleClient);
        }

        /// <summary>
        /// This method is called whenever the module is sent a message from the EdgeHub. 
        /// It just pipe the messages without any change.
        /// It prints all the incoming messages.
        /// </summary>
        static async Task<MessageResponse> PipeMessage(Message message, object userContext)
        {
            int counterValue = Interlocked.Increment(ref counter);

            var moduleClient = userContext as ModuleClient;
            if (moduleClient == null)
            {
                throw new InvalidOperationException("UserContext doesn't contain " + "expected values");
            }

            byte[] messageBytes = message.GetBytes();
            string messageString = Encoding.UTF8.GetString(messageBytes);
            logger.LogInformation($"Received message: {counterValue}, Body: [{messageString}]");

            if (!string.IsNullOrEmpty(messageString))
            {
                using (var pipeMessage = new Message(messageBytes))
                {
                    foreach (var prop in message.Properties)
                    {
                        pipeMessage.Properties.Add(prop.Key, prop.Value);
                    }
                    await moduleClient.SendEventAsync("output1", pipeMessage);

                    logger.LogInformation("Received message sent");
                }
            }
            return MessageResponse.Completed;
        }

        /// <summary>
        /// This method is called whenever the module is sent a message from the EdgeHub. 
        /// It just pipe the messages without any change.
        /// It prints all the incoming messages.
        /// </summary>
        static async Task<MethodResponse> ExecuteSqlCommandAsync(MethodRequest methodRequest, object userContext)
        {
            try
            {
                logger.LogInformation("ExecuteSqlCommandAsync method started");
                logger.LogDebug($"ExecuteSqlCommandAsync method payload: {Encoding.UTF8.GetString(methodRequest.Data)}");

                var moduleClient = userContext as ModuleClient;
                if (moduleClient == null)
                {
                    throw new InvalidOperationException("UserContext doesn't contain " + "expected values");
                }

                ExecuteSqlCommand executeSqlCommand = JsonConvert.DeserializeObject<ExecuteSqlCommand>(Encoding.UTF8.GetString(methodRequest.Data));
                string connectionString = SqlHelper.GenerateConnectionString(executeSqlCommand.DataSource, executeSqlCommand.Database, executeSqlCommand.UserId, executeSqlCommand.Password);
                logger.LogDebug($"Connection string: {connectionString}");

                string queryResponse = await SqlHelper.ExecuteCommand(connectionString, executeSqlCommand.Command);
                logger.LogDebug($"query response: {queryResponse}");
                
                return new MethodResponse(Encoding.UTF8.GetBytes(queryResponse), 200);
            }
            catch (Exception e)
            {
                logger.LogError(e.ToString());
                return new MethodResponse(Encoding.UTF8.GetBytes(e.ToString()), 500);
            }
        }
    }
}
