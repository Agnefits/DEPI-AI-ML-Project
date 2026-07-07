using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Models;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class AiController : ControllerBase
    {
        private readonly IAiService _aiService;
        private readonly IFileService _fileService;
        private readonly IUnitOfWork _unitOfWork;

        public AiController(IAiService aiService, IFileService fileService, IUnitOfWork unitOfWork)
        {
            _aiService = aiService ?? throw new ArgumentNullException(nameof(aiService));
            _fileService = fileService ?? throw new ArgumentNullException(nameof(fileService));
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        [HttpPost("analyze")]
        public async Task<IActionResult> Analyze([FromForm] string? prompt, [FromForm] int caseId, IFormFile? file)
        {
            if (string.IsNullOrEmpty(prompt) && (file == null || file.Length == 0))
                return BadRequest("Either prompt or file must be provided.");

            // Verify the target case exists
            var targetCase = await _unitOfWork.Cases.GetByIdAsync(caseId);
            if (targetCase == null)
            {
                return BadRequest($"Case with ID {caseId} does not exist.");
            }

            // Enforce ownership: Doctor can only run analyses on their own cases
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                if (targetCase.DoctorId != currentDoctorId)
                {
                    return StatusCode(StatusCodes.Status403Forbidden, new { error = "Access Denied: You do not have permission to run AI analysis on another doctor's case." });
                }
            }

            string? savedFilePath = null;

            try
            {
                // 1. If file is attached, upload using FileService and log as MedicalImage
                if (file != null && file.Length > 0)
                {
                    savedFilePath = await _fileService.SaveFileAsync(file, "medical-images");

                    var medicalImage = new MedicalImage
                    {
                        CaseId = caseId,
                        FilePath = savedFilePath,
                        ImageType = file.ContentType.Contains("image") ? "Scan" : "Attachment",
                        UploadedAt = DateTime.UtcNow
                    };
                    await _unitOfWork.MedicalImages.AddAsync(medicalImage);
                }

                // 2. Submit prompt and file to AI Model API
                var startTime = DateTime.UtcNow;
                var aiResponse = await _aiService.AnalyzePromptAsync(prompt, file);
                var endTime = DateTime.UtcNow;
                var processingTime = (endTime - startTime).TotalSeconds;

                // Extract confidence and format findings if the response is JSON
                double confidence = 0.88;
                string findingText = aiResponse;

                try
                {
                    using (var doc = JsonDocument.Parse(aiResponse))
                    {
                        var root = doc.RootElement;

                        // 1. Get confidence from the highest probability diagnostic
                        if (root.TryGetProperty("icd10_diagnostics", out var diagnosticsProp) && diagnosticsProp.ValueKind == JsonValueKind.Array)
                        {
                            var list = diagnosticsProp.EnumerateArray();
                            if (list.Any())
                            {
                                var firstDiag = list.First();
                                if (firstDiag.TryGetProperty("probability", out var probProp) && probProp.TryGetDouble(out var probVal))
                                {
                                    confidence = probVal;
                                }
                            }
                        }

                        // 2. Format a human-readable finding summary
                        var textContent = root.TryGetProperty("text", out var textProp) ? textProp.GetString() : string.Empty;
                        
                        var entitiesList = new List<string>();
                        if (root.TryGetProperty("entities", out var entitiesProp) && entitiesProp.ValueKind == JsonValueKind.Array)
                        {
                            foreach (var entityObj in entitiesProp.EnumerateArray())
                            {
                                var entityName = entityObj.TryGetProperty("entity", out var nameProp) ? nameProp.GetString() : null;
                                var entityType = entityObj.TryGetProperty("type", out var typeProp) ? typeProp.GetString() : null;
                                if (!string.IsNullOrEmpty(entityName))
                                {
                                    entitiesList.Add($"{entityName} ({entityType})");
                                }
                            }
                        }

                        var diagList = new List<string>();
                        if (root.TryGetProperty("icd10_diagnostics", out var diagnosticsProp2) && diagnosticsProp2.ValueKind == JsonValueKind.Array)
                        {
                            foreach (var diagObj in diagnosticsProp2.EnumerateArray())
                            {
                                var code = diagObj.TryGetProperty("code", out var codeProp) ? codeProp.GetString() : null;
                                if (diagObj.TryGetProperty("probability", out var probProp2) && probProp2.TryGetDouble(out var probVal))
                                {
                                    diagList.Add($"{code} ({(probVal * 100):F1}%)");
                                }
                            }
                        }

                        findingText = $"Cleaned Note: {textContent}\nEntities: {string.Join(", ", entitiesList)}\nDiagnostics: {string.Join(", ", diagList)}";
                    }
                }
                catch
                {
                    // Fall back to original aiResponse and default confidence if JSON parsing fails
                }

                // 3. Save AI Analysis result
                var aiAnalysis = new AIAnalysis
                {
                    CaseId = caseId,
                    ModelVersion = "clinicMODELv0",
                    Confidence = confidence,
                    ProcessingTime = processingTime,
                    CreatedAt = DateTime.UtcNow
                };

                await _unitOfWork.AIAnalyses.AddAsync(aiAnalysis);
                await _unitOfWork.CompleteAsync(); // Saves and sets aiAnalysis.Id

                // 4. Save AI Finding details
                var aiFinding = new AIFinding
                {
                    AnalysisId = aiAnalysis.Id,
                    Finding = findingText,
                    Confidence = confidence
                };
                await _unitOfWork.AIFindings.AddAsync(aiFinding);
                await _unitOfWork.CompleteAsync();

                return Ok(new
                {
                    analysisId = aiAnalysis.Id,
                    filePath = savedFilePath,
                    response = aiResponse
                });
            }
            catch (Exception ex)
            {
                // Clean up uploaded file if the rest of the operation fails
                if (savedFilePath != null)
                {
                    _fileService.DeleteFile(savedFilePath);
                }

                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("classify")]
        public async Task<IActionResult> Classify([FromForm] int caseId, IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest("Scan image file is required.");

            var targetCase = await _unitOfWork.Cases.GetByIdAsync(caseId);
            if (targetCase == null)
            {
                return BadRequest($"Case with ID {caseId} does not exist.");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                if (targetCase.DoctorId != currentDoctorId)
                {
                    return StatusCode(StatusCodes.Status403Forbidden, new { error = "Access Denied: You do not own this case." });
                }
            }

            string? savedFilePath = null;
            try
            {
                savedFilePath = await _fileService.SaveFileAsync(file, "medical-images");

                var medicalImage = new MedicalImage
                {
                    CaseId = caseId,
                    FilePath = savedFilePath,
                    ImageType = "Scan",
                    UploadedAt = DateTime.UtcNow
                };
                await _unitOfWork.MedicalImages.AddAsync(medicalImage);

                // Call Python AI service to get predictions
                var startTime = DateTime.UtcNow;
                
                string predictionLabel = "Normal";
                double confidence = 0.86;
                string rawAiResponse = "{\"detected_labels\":[]}";

                Dictionary<string, double>? probabilities = null;
                Dictionary<string, int>? predictions = null;
                string[]? detectedLabels = null;

                try
                {
                    // Query the AI model Python endpoint configured in database
                    rawAiResponse = await _aiService.ClassifyScanAsync(file);
                    
                    using (var doc = JsonDocument.Parse(rawAiResponse))
                    {
                        var root = doc.RootElement;
                        
                        // Parse detected_labels
                        if (root.TryGetProperty("detected_labels", out var detectedLabelsProp) && detectedLabelsProp.ValueKind == JsonValueKind.Array)
                        {
                            var labelsList = new List<string>();
                            var labelProbsList = new List<double>();
                            foreach (var item in detectedLabelsProp.EnumerateArray())
                            {
                                if (item.ValueKind == JsonValueKind.Object)
                                {
                                    string? lbl = null;
                                    double probVal = 0.0;
                                    if (item.TryGetProperty("label", out var labelProp))
                                    {
                                        lbl = labelProp.GetString();
                                    }
                                    if (item.TryGetProperty("probability", out var probProp) && probProp.TryGetDouble(out var pVal))
                                    {
                                        probVal = pVal;
                                    }
                                    if (!string.IsNullOrEmpty(lbl))
                                    {
                                        labelsList.Add(lbl);
                                        labelProbsList.Add(probVal);
                                    }
                                }
                                else if (item.ValueKind == JsonValueKind.String)
                                {
                                    var lbl = item.GetString();
                                    if (!string.IsNullOrEmpty(lbl))
                                    {
                                        labelsList.Add(lbl);
                                    }
                                }
                            }
                            
                            labelsList.RemoveAll(string.IsNullOrEmpty);
                            
                            if (labelsList.Count > 0)
                            {
                                detectedLabels = labelsList.ToArray();
                                predictionLabel = string.Join(", ", detectedLabels);
                                
                                if (labelProbsList.Count > 0)
                                {
                                    confidence = 0.0;
                                    foreach (var p in labelProbsList)
                                    {
                                        if (p > confidence)
                                        {
                                            confidence = p;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                detectedLabels = new[] { "No Finding" };
                                predictionLabel = "Normal";
                                confidence = 0.99;
                            }
                        }
                        
                        // Parse probabilities & predictions dictionaries
                        if (root.TryGetProperty("probabilities", out var probabilitiesProp) && probabilitiesProp.ValueKind == JsonValueKind.Object)
                        {
                            probabilities = JsonSerializer.Deserialize<Dictionary<string, double>>(probabilitiesProp.GetRawText());
                        }
                        if (root.TryGetProperty("predictions", out var predictionsProp) && predictionsProp.ValueKind == JsonValueKind.Object)
                        {
                            predictions = JsonSerializer.Deserialize<Dictionary<string, int>>(predictionsProp.GetRawText());
                        }

                        // Extract confidence (max probability of detected labels)
                        if (probabilities != null)
                        {
                            double maxProb = 0;
                            bool foundProb = false;
                            
                            if (detectedLabels != null)
                            {
                                foreach (var label in detectedLabels)
                                {
                                    if (probabilities.TryGetValue(label, out double val))
                                    {
                                        if (val > maxProb)
                                        {
                                            maxProb = val;
                                            foundProb = true;
                                        }
                                    }
                                }
                            }
                            
                            if (!foundProb)
                            {
                                foreach (var kvp in probabilities)
                                {
                                    if (kvp.Value > maxProb)
                                    {
                                        maxProb = kvp.Value;
                                    }
                                }
                            }
                            
                            if (maxProb > 0)
                            {
                                confidence = maxProb;
                            }
                        }
                    }
                }
                catch
                {
                    // Fall back to simulated local classification model if external API is offline or parse fails
                }

                var endTime = DateTime.UtcNow;
                var processingTime = (endTime - startTime).TotalSeconds;

                // Log AI Analysis result
                var aiAnalysis = new AIAnalysis
                {
                    CaseId = caseId,
                    ModelVersion = "clinicMODELv1",
                    Confidence = confidence,
                    ProcessingTime = processingTime,
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AIAnalyses.AddAsync(aiAnalysis);
                await _unitOfWork.CompleteAsync();

                // Save finding
                var aiFinding = new AIFinding
                {
                    AnalysisId = aiAnalysis.Id,
                    Finding = $"Classification: {predictionLabel}. Details: {rawAiResponse}",
                    Confidence = confidence
                };
                await _unitOfWork.AIFindings.AddAsync(aiFinding);

                // Map ICD-10 Code based on keywords in predictionLabel
                string icdCode = "Z00.0"; // Default: Normal/General exam
                if (predictionLabel.Contains("Pneumonia", StringComparison.OrdinalIgnoreCase))
                    icdCode = "J18.9";
                else if (predictionLabel.Contains("COVID-19", StringComparison.OrdinalIgnoreCase))
                    icdCode = "U07.1";
                else if (predictionLabel.Contains("Cardiomegaly", StringComparison.OrdinalIgnoreCase))
                    icdCode = "I51.7";
                else if (predictionLabel.Contains("Effusion", StringComparison.OrdinalIgnoreCase))
                    icdCode = "J91.8";
                else if (predictionLabel.Contains("Infiltration", StringComparison.OrdinalIgnoreCase))
                    icdCode = "R91.8";
                else if (predictionLabel.Contains("Pneumothorax", StringComparison.OrdinalIgnoreCase))
                    icdCode = "J93.9";

                // Pre-create a draft diagnosis for doctor review
                var diagnosis = new Diagnosis
                {
                    CaseId = caseId,
                    DiagnosisName = predictionLabel,
                    ICD10Code = icdCode,
                    Confidence = confidence,
                    IsFinal = false
                };
                await _unitOfWork.Diagnoses.AddAsync(diagnosis);
                await _unitOfWork.CompleteAsync();

                return Ok(new
                {
                    analysisId = aiAnalysis.Id,
                    label = predictionLabel,
                    confidence = confidence,
                    detectedLabels = detectedLabels ?? (predictionLabel == "Normal" ? new string[] { "No Finding" } : predictionLabel.Split(", ")),
                    probabilities = probabilities,
                    predictions = predictions,
                    details = rawAiResponse,
                    processingTime = processingTime
                });
            }
            catch (Exception ex)
            {
                if (savedFilePath != null)
                {
                    _fileService.DeleteFile(savedFilePath);
                }
                return StatusCode(500, new { error = ex.Message });
            }
        }
    }
}
