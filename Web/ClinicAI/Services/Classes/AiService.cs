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
                // Set Auth bearer token or other headers required by the target AI API
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
            }

            var multipartContent = new MultipartFormDataContent();
            
            // Add prompt text parameter
            multipartContent.Add(new StringContent(prompt), "prompt");

            // Add model parameter if specified
            if (!string.IsNullOrEmpty(modelName))
            {
                multipartContent.Add(new StringContent(modelName), "model");
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

            var response = await _httpClient.SendAsync(request);
            if (!response.IsSuccessStatusCode)
            {
                var errorDetails = await response.Content.ReadAsStringAsync();
                throw new HttpRequestException($"AI API request failed. Status: {response.StatusCode}, Details: {errorDetails}");
            }

            return await response.Content.ReadAsStringAsync();
        }
    }
}
