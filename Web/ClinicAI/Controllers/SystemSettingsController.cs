using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;
using ClinicAI.ViewModels.SystemSettings;

using ClinicAI.Attributes;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("SuperAdmin")]
    public class SystemSettingsController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public SystemSettingsController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        // Display current Settings (GET)
        public async Task<IActionResult> Index()
        {
            var settings = await _unitOfWork.SystemSettings.GetAllAsync();
            var list = settings.ToList();

            var viewModel = new SystemSettingsVM
            {
                // Storage settings mapping
                MaxUploadSizeMb = int.TryParse(list.FirstOrDefault(s => s.Group == "Storage" && s.Key == "MaxUploadSizeMb")?.Value, out var sz) ? sz : 25,
                AllowedExtensions = list.FirstOrDefault(s => s.Group == "Storage" && s.Key == "AllowedExtensions")?.Value ?? ".jpg,.jpeg,.png,.pdf",
                StoragePath = list.FirstOrDefault(s => s.Group == "Storage" && s.Key == "StoragePath")?.Value ?? "wwwroot/uploads/",

                // AI settings mapping
                ClassifyApiUrl = list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ClassifyApiUrl")?.Value 
                    ?? list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ApiUrl")?.Value 
                    ?? "",
                ClassifyApiKey = list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ClassifyApiKey")?.Value 
                    ?? list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ApiKey")?.Value 
                    ?? "",
                ClassifyModelName = list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ClassifyModelName")?.Value 
                    ?? list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ModelName")?.Value 
                    ?? "clinicMODELv1",

                AnalyzeApiUrl = list.FirstOrDefault(s => s.Group == "AI" && s.Key == "AnalyzeApiUrl")?.Value 
                    ?? list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ApiUrl")?.Value 
                    ?? "",
                AnalyzeApiKey = list.FirstOrDefault(s => s.Group == "AI" && s.Key == "AnalyzeApiKey")?.Value 
                    ?? list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ApiKey")?.Value 
                    ?? "",
                AnalyzeModelName = list.FirstOrDefault(s => s.Group == "AI" && s.Key == "AnalyzeModelName")?.Value 
                    ?? list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ModelName")?.Value 
                    ?? "clinicMODELv0",

                ConfidenceThreshold = double.TryParse(list.FirstOrDefault(s => s.Group == "AI" && s.Key == "ConfidenceThreshold")?.Value, out var th) ? th : 0.70,

                // SMTP settings mapping
                SmtpHost = list.FirstOrDefault(s => s.Group == "Email" && s.Key == "SmtpHost")?.Value ?? "smtp.gmail.com",
                SmtpPort = int.TryParse(list.FirstOrDefault(s => s.Group == "Email" && s.Key == "SmtpPort")?.Value, out var pt) ? pt : 587,
                SenderEmail = list.FirstOrDefault(s => s.Group == "Email" && s.Key == "SenderEmail")?.Value ?? "",
                SenderPassword = list.FirstOrDefault(s => s.Group == "Email" && s.Key == "SenderPassword")?.Value ?? "",
                EnableSsl = bool.TryParse(list.FirstOrDefault(s => s.Group == "Email" && s.Key == "EnableSsl")?.Value, out var ssl) ? ssl : true,

                // Mobile settings mapping
                ApkDownloadUrl = list.FirstOrDefault(s => s.Group == "Mobile" && s.Key == "ApkDownloadUrl")?.Value ?? ""
            };

            return View(viewModel);
        }

        // Save changed Settings (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Save(SystemSettingsVM model)
        {
            if (ModelState.IsValid)
            {
                var settings = await _unitOfWork.SystemSettings.GetAllAsync();
                var list = settings.ToList();

                // 1. Update Storage settings
                await UpdateOrInsertSettingAsync(list, "Storage", "MaxUploadSizeMb", model.MaxUploadSizeMb.ToString());
                await UpdateOrInsertSettingAsync(list, "Storage", "AllowedExtensions", model.AllowedExtensions);
                await UpdateOrInsertSettingAsync(list, "Storage", "StoragePath", model.StoragePath);

                // 2. Update AI settings
                await UpdateOrInsertSettingAsync(list, "AI", "ClassifyApiUrl", model.ClassifyApiUrl);
                await UpdateOrInsertSettingAsync(list, "AI", "ClassifyApiKey", model.ClassifyApiKey);
                await UpdateOrInsertSettingAsync(list, "AI", "ClassifyModelName", model.ClassifyModelName);
                await UpdateOrInsertSettingAsync(list, "AI", "AnalyzeApiUrl", model.AnalyzeApiUrl);
                await UpdateOrInsertSettingAsync(list, "AI", "AnalyzeApiKey", model.AnalyzeApiKey);
                await UpdateOrInsertSettingAsync(list, "AI", "AnalyzeModelName", model.AnalyzeModelName);
                await UpdateOrInsertSettingAsync(list, "AI", "ConfidenceThreshold", model.ConfidenceThreshold.ToString());

                // 3. Update Email settings
                await UpdateOrInsertSettingAsync(list, "Email", "SmtpHost", model.SmtpHost);
                await UpdateOrInsertSettingAsync(list, "Email", "SmtpPort", model.SmtpPort.ToString());
                await UpdateOrInsertSettingAsync(list, "Email", "SenderEmail", model.SenderEmail);
                await UpdateOrInsertSettingAsync(list, "Email", "SenderPassword", model.SenderPassword);
                await UpdateOrInsertSettingAsync(list, "Email", "EnableSsl", model.EnableSsl.ToString());

                // 4. Update Mobile settings
                await UpdateOrInsertSettingAsync(list, "Mobile", "ApkDownloadUrl", model.ApkDownloadUrl);

                await _unitOfWork.CompleteAsync();

                // Log system action
                var auditLog = new AuditLog
                {
                    UserId = 1, // Default Admin
                    Action = "Update System Settings",
                    EntityName = "SystemSetting",
                    EntityId = 0,
                    NewValue = "System configuration settings updated by administrator.",
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();

                TempData["SuccessMessage"] = "System settings updated successfully!";
                return RedirectToAction(nameof(Index));
            }

            return View("Index", model);
        }

        private async Task UpdateOrInsertSettingAsync(List<SystemSetting> list, string group, string key, string value)
        {
            var setting = list.FirstOrDefault(s => s.Group == group && s.Key == key);
            if (setting != null)
            {
                setting.Value = value ?? "";
                _unitOfWork.SystemSettings.Update(setting);
            }
            else
            {
                var newSetting = new SystemSetting
                {
                    Group = group,
                    Key = key,
                    Value = value ?? ""
                };
                await _unitOfWork.SystemSettings.AddAsync(newSetting);
            }
        }
    }
}
