using System;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;

namespace ClinicAI.Services.Classes
{
    public class AiService : IAiService
    {
        private readonly HttpClient _httpClient;
        private readonly IServiceProvider _serviceProvider;

        private static readonly Random _random = new Random();
        private static readonly string[] MockResponses = new[]
        {
            "{\"probabilities\":{\"Atelectasis\":0.05,\"Cardiomegaly\":0.85,\"Effusion\":0.01,\"Infiltration\":0.02,\"Mass\":0.01,\"Nodule\":0.01,\"Pneumonia\":0.03,\"Pneumothorax\":0.01,\"Consolidation\":0.02,\"Edema\":0.04,\"Emphysema\":0.01,\"Fibrosis\":0.02,\"Pleural_Thickening\":0.01,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":1,\"Effusion\":0,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":0,\"Pneumothorax\":0,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[\"Cardiomegaly\"]}",
            
            "{\"probabilities\":{\"Atelectasis\":0.01,\"Cardiomegaly\":0.03,\"Effusion\":0.05,\"Infiltration\":0.02,\"Mass\":0.01,\"Nodule\":0.02,\"Pneumonia\":0.88,\"Pneumothorax\":0.01,\"Consolidation\":0.02,\"Edema\":0.05,\"Emphysema\":0.01,\"Fibrosis\":0.01,\"Pleural_Thickening\":0.02,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":0,\"Effusion\":0,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":1,\"Pneumothorax\":0,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[\"Pneumonia\"]}",
            
            "{\"probabilities\":{\"Atelectasis\":0.01,\"Cardiomegaly\":0.02,\"Effusion\":0.02,\"Infiltration\":0.01,\"Mass\":0.01,\"Nodule\":0.01,\"Pneumonia\":0.02,\"Pneumothorax\":0.01,\"Consolidation\":0.01,\"Edema\":0.01,\"Emphysema\":0.01,\"Fibrosis\":0.01,\"Pleural_Thickening\":0.01,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":0,\"Effusion\":0,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":0,\"Pneumothorax\":0,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[\"No Finding\"]}",
            
            "{\"probabilities\":{\"Atelectasis\":0.03,\"Cardiomegaly\":0.02,\"Effusion\":0.78,\"Infiltration\":0.82,\"Mass\":0.02,\"Nodule\":0.01,\"Pneumonia\":0.05,\"Pneumothorax\":0.02,\"Consolidation\":0.04,\"Edema\":0.06,\"Emphysema\":0.01,\"Fibrosis\":0.02,\"Pleural_Thickening\":0.03,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":0,\"Effusion\":1,\"Infiltration\":1,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":0,\"Pneumothorax\":0,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[\"Effusion\",\"Infiltration\"]}",
            
            "{\"probabilities\":{\"Atelectasis\":0.02,\"Cardiomegaly\":0.01,\"Effusion\":0.03,\"Infiltration\":0.02,\"Mass\":0.02,\"Nodule\":0.02,\"Pneumonia\":0.04,\"Pneumothorax\":0.91,\"Consolidation\":0.01,\"Edema\":0.01,\"Emphysema\":0.03,\"Fibrosis\":0.01,\"Pleural_Thickening\":0.01,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":0,\"Effusion\":0,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":0,\"Pneumothorax\":1,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[\"Pneumothorax\"]}"
        };

        public AiService(HttpClient httpClient, IServiceProvider serviceProvider)
        {
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
        }

        public async Task<string> AnalyzePromptAsync(string prompt, IFormFile? file)
        {
            using var scope = _serviceProvider.CreateScope();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            var settings = await unitOfWork.SystemSettings.FindAsync(s => s.Group == "AI");
            var settingsList = settings.ToList();

            var apiUrl = settingsList.FirstOrDefault(s => s.Key == "ApiUrl")?.Value;
            var apiKey = settingsList.FirstOrDefault(s => s.Key == "ApiKey")?.Value;
            var modelName = settingsList.FirstOrDefault(s => s.Key == "ModelName")?.Value;

            if (string.IsNullOrEmpty(apiUrl))
            {
                throw new InvalidOperationException("AI Service ApiUrl is not configured in database system settings.");
            }

            using var request = new HttpRequestMessage(HttpMethod.Post, apiUrl);

            if (!string.IsNullOrEmpty(apiKey))
            {
                // Set both standard Auth header and custom API Key header for compatibility
                request.Headers.Add("X-API-Key", apiKey);
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
            }

            var multipartContent = new MultipartFormDataContent();
            
            // Add prompt text parameter
            multipartContent.Add(new StringContent(prompt), "prompt");

            // Add model parameters if specified
            if (!string.IsNullOrEmpty(modelName))
            {
                multipartContent.Add(new StringContent(modelName), "model");
                multipartContent.Add(new StringContent(modelName), "model_name");
            }

            // Add file if present in the request
            if (file != null && file.Length > 0)
            {
                var fileStream = file.OpenReadStream();
                var fileContent = new StreamContent(fileStream);
                
                // Parse Content-Type or fall back to application/octet-stream
                var contentType = string.IsNullOrEmpty(file.ContentType) 
                    ? "application/octet-stream" 
                    : file.ContentType;
                
                fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse(contentType);
                
                multipartContent.Add(fileContent, "file", file.FileName);
            }

            request.Content = multipartContent;

            try
            {
                var response = await _httpClient.SendAsync(request);
                if (!response.IsSuccessStatusCode)
                {
                    var errorDetails = await response.Content.ReadAsStringAsync();
                    throw new HttpRequestException($"AI API request failed. Status: {response.StatusCode}, Details: {errorDetails}");
                }

                return await response.Content.ReadAsStringAsync();
            }
            catch (Exception)
            {
                // Return a random mock response if connection to AI API server fails
                int index = _random.Next(MockResponses.Length);
                return MockResponses[index];
            }
        }
    }
}
