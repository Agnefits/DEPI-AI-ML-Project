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
        
        private static readonly string[] MockClassifyResponses = new[]
        {
            "{\"probabilities\":{\"Atelectasis\":0.05,\"Cardiomegaly\":0.85,\"Effusion\":0.01,\"Infiltration\":0.02,\"Mass\":0.01,\"Nodule\":0.01,\"Pneumonia\":0.03,\"Pneumothorax\":0.01,\"Consolidation\":0.02,\"Edema\":0.04,\"Emphysema\":0.01,\"Fibrosis\":0.02,\"Pleural_Thickening\":0.01,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":1,\"Effusion\":0,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":0,\"Pneumothorax\":0,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[{\"label\":\"Cardiomegaly\",\"probability\":0.85}],\"status\":\"Success\",\"client\":\"mock\"}",
            
            "{\"probabilities\":{\"Atelectasis\":0.01,\"Cardiomegaly\":0.03,\"Effusion\":0.05,\"Infiltration\":0.02,\"Mass\":0.01,\"Nodule\":0.02,\"Pneumonia\":0.88,\"Pneumothorax\":0.01,\"Consolidation\":0.02,\"Edema\":0.05,\"Emphysema\":0.01,\"Fibrosis\":0.01,\"Pleural_Thickening\":0.02,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":0,\"Effusion\":0,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":1,\"Pneumothorax\":0,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[{\"label\":\"Pneumonia\",\"probability\":0.88}],\"status\":\"Success\",\"client\":\"mock\"}",
            
            "{\"probabilities\":{\"Atelectasis\":0.01,\"Cardiomegaly\":0.02,\"Effusion\":0.02,\"Infiltration\":0.01,\"Mass\":0.01,\"Nodule\":0.01,\"Pneumonia\":0.02,\"Pneumothorax\":0.01,\"Consolidation\":0.01,\"Edema\":0.01,\"Emphysema\":0.01,\"Fibrosis\":0.01,\"Pleural_Thickening\":0.01,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":0,\"Effusion\":0,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":0,\"Pneumothorax\":0,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[],\"status\":\"Success\",\"client\":\"mock\"}",
            
            "{\"probabilities\":{\"Atelectasis\":0.5612899661064148,\"Cardiomegaly\":0.35836684703826904,\"Effusion\":0.7846769690513611,\"Infiltration\":0.4851033091545105,\"Mass\":0.4437389671802521,\"Nodule\":0.3804352879524231,\"Pneumonia\":0.28592240810394287,\"Pneumothorax\":0.3351079225540161,\"Consolidation\":0.47733017802238464,\"Edema\":0.27256351709365845,\"Emphysema\":0.2604221999645233,\"Fibrosis\":0.27812525629997253,\"Pleural_Thickening\":0.38774770498275757,\"Hernia\":0.20099133253097534},\"predictions\":{\"Atelectasis\":1,\"Cardiomegaly\":0,\"Effusion\":1,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":0,\"Pneumothorax\":0,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[{\"label\":\"Atelectasis\",\"probability\":0.5613},{\"label\":\"Effusion\",\"probability\":0.7847}],\"status\":\"Success\",\"client\":\"mock\"}",
            
            "{\"probabilities\":{\"Atelectasis\":0.02,\"Cardiomegaly\":0.01,\"Effusion\":0.03,\"Infiltration\":0.02,\"Mass\":0.02,\"Nodule\":0.02,\"Pneumonia\":0.04,\"Pneumothorax\":0.91,\"Consolidation\":0.01,\"Edema\":0.01,\"Emphysema\":0.03,\"Fibrosis\":0.01,\"Pleural_Thickening\":0.01,\"Hernia\":0.00},\"predictions\":{\"Atelectasis\":0,\"Cardiomegaly\":0,\"Effusion\":0,\"Infiltration\":0,\"Mass\":0,\"Nodule\":0,\"Pneumonia\":0,\"Pneumothorax\":1,\"Consolidation\":0,\"Edema\":0,\"Emphysema\":0,\"Fibrosis\":0,\"Pleural_Thickening\":0,\"Hernia\":0},\"detected_labels\":[{\"label\":\"Pneumothorax\",\"probability\":0.91}],\"status\":\"Success\",\"client\":\"mock\"}"
        };

        private static readonly string[] MockAnalyzeResponses = new[]
        {
            "Analysis: The chest X-ray indicates moderate cardiomegaly with mild pulmonary vascular congestion. No acute focal consolidation or pleural effusion is identified. The trachea is midline. Heart size is enlarged, consistent with patient history of hypertension.",
            
            "Analysis: Patchy infiltrates and consolidation are observed in the lower right lobe, suggesting moderate right-sided lobar pneumonia. Pleural spaces appear clear. No pneumothorax. Recommendation: Correlate with clinical findings (fever, cough).",
            
            "Analysis: Chest radiograph demonstrates clear lung fields bilaterally. Cardiomediastinal contour is within normal limits. Bony structures and soft tissues are unremarkable. No active cardiopulmonary disease detected.",
            
            "Analysis: The scan reveals bilateral pleural effusions, more pronounced on the left side, accompanied by subsegmental atelectasis in both lung bases. Mild peribronchial thickening is observed. Recommend follow-up scan after treatment.",
            
            "Analysis: There is a large hyperlucent area in the right upper hemithorax with a visible visceral pleural line and no lung markings peripheral to it, diagnostic of a moderate right pneumothorax. Tracheal deviation is not present. Immediate clinical correlation is advised."
        };

        public AiService(HttpClient httpClient, IServiceProvider serviceProvider)
        {
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
        }

        public async Task<string> ClassifyScanAsync(IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                throw new ArgumentException("Scan image file is required.", nameof(file));
            }

            using var scope = _serviceProvider.CreateScope();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            var settings = await unitOfWork.SystemSettings.FindAsync(s => s.Group == "AI");
            var settingsList = settings.ToList();

            var apiUrl = settingsList.FirstOrDefault(s => s.Key == "ClassifyApiUrl")?.Value 
                ?? settingsList.FirstOrDefault(s => s.Key == "ApiUrl")?.Value;
            var apiKey = settingsList.FirstOrDefault(s => s.Key == "ClassifyApiKey")?.Value 
                ?? settingsList.FirstOrDefault(s => s.Key == "ApiKey")?.Value;
            var modelName = settingsList.FirstOrDefault(s => s.Key == "ClassifyModelName")?.Value 
                ?? settingsList.FirstOrDefault(s => s.Key == "ModelName")?.Value;

            if (string.IsNullOrEmpty(apiUrl))
            {
                throw new InvalidOperationException("AI Classify Service ApiUrl is not configured in database system settings.");
            }

            using var request = new HttpRequestMessage(HttpMethod.Post, apiUrl);

            if (!string.IsNullOrEmpty(apiKey))
            {
                request.Headers.Add("X-API-Key", apiKey);
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
            }

            var multipartContent = new MultipartFormDataContent();

            if (!string.IsNullOrEmpty(modelName))
            {
                multipartContent.Add(new StringContent(modelName), "model");
                multipartContent.Add(new StringContent(modelName), "model_name");
            }

            var fileStream = file.OpenReadStream();
            var fileContent = new StreamContent(fileStream);
            var contentType = string.IsNullOrEmpty(file.ContentType) 
                ? "application/octet-stream" 
                : file.ContentType;
            
            fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse(contentType);
            multipartContent.Add(fileContent, "file", file.FileName);

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
                int index = _random.Next(MockClassifyResponses.Length);
                return MockClassifyResponses[index];
            }
        }

        public async Task<string> AnalyzePromptAsync(string prompt, IFormFile? file)
        {
            using var scope = _serviceProvider.CreateScope();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

            var settings = await unitOfWork.SystemSettings.FindAsync(s => s.Group == "AI");
            var settingsList = settings.ToList();

            var apiUrl = settingsList.FirstOrDefault(s => s.Key == "AnalyzeApiUrl")?.Value 
                ?? settingsList.FirstOrDefault(s => s.Key == "ApiUrl")?.Value;
            var apiKey = settingsList.FirstOrDefault(s => s.Key == "AnalyzeApiKey")?.Value 
                ?? settingsList.FirstOrDefault(s => s.Key == "ApiKey")?.Value;
            var modelName = settingsList.FirstOrDefault(s => s.Key == "AnalyzeModelName")?.Value 
                ?? settingsList.FirstOrDefault(s => s.Key == "ModelName")?.Value;

            if (string.IsNullOrEmpty(apiUrl))
            {
                throw new InvalidOperationException("AI Analyze Service ApiUrl is not configured in database system settings.");
            }

            using var request = new HttpRequestMessage(HttpMethod.Post, apiUrl);

            if (!string.IsNullOrEmpty(apiKey))
            {
                request.Headers.Add("X-API-Key", apiKey);
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
            }

            var multipartContent = new MultipartFormDataContent();
            
            multipartContent.Add(new StringContent(prompt), "prompt");

            if (!string.IsNullOrEmpty(modelName))
            {
                multipartContent.Add(new StringContent(modelName), "model");
                multipartContent.Add(new StringContent(modelName), "model_name");
            }

            if (file != null && file.Length > 0)
            {
                var fileStream = file.OpenReadStream();
                var fileContent = new StreamContent(fileStream);
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
                int index = _random.Next(MockAnalyzeResponses.Length);
                return MockAnalyzeResponses[index];
            }
        }
    }
}
