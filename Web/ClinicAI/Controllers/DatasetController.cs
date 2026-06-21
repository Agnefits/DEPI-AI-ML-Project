using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using ClinicAI.Models;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;
using ClinicAI.ViewModels.Dataset;

using ClinicAI.Attributes;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("Admin", "SuperAdmin")]
    public class DatasetController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IFileService _fileService;

        public DatasetController(IUnitOfWork unitOfWork, IFileService fileService)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _fileService = fileService ?? throw new ArgumentNullException(nameof(fileService));
        }

        // List Uploaded Dataset Items
        public async Task<IActionResult> Index()
        {
            var items = await _unitOfWork.DatasetItems.GetAllAsync();
            
            var viewModel = new DatasetUploadVM
            {
                UploadedItems = items.OrderByDescending(i => i.UploadedAt).ToList(),
                LabelsList = GetPredefinedLabels()
            };

            return View(viewModel);
        }

        // Upload New Dataset Item (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Upload(DatasetUploadVM model)
        {
            if (model.ImageFile == null || model.ImageFile.Length == 0)
            {
                ModelState.AddModelError("ImageFile", "Please upload a valid scan image file.");
            }

            if (string.IsNullOrEmpty(model.Label))
            {
                ModelState.AddModelError("Label", "Please assign a label classifying the scan.");
            }

            if (ModelState.IsValid)
            {
                // Save image file under wwwroot/uploads/dataset/ using FileService
                var imagePath = await _fileService.SaveFileAsync(model.ImageFile!, "dataset");

                var item = new DatasetItem
                {
                    ImagePath = imagePath,
                    Label = model.Label,
                    UploadedAt = DateTime.UtcNow
                };

                await _unitOfWork.DatasetItems.AddAsync(item);
                await _unitOfWork.CompleteAsync();

                // Save Audit Log entry
                var auditLog = new AuditLog
                {
                    UserId = 1, // Fallback default admin ID
                    Action = "Upload Dataset Item",
                    EntityName = "DatasetItem",
                    EntityId = item.Id,
                    NewValue = $"Uploaded retraining scan. Label: '{model.Label}'",
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }

            // Reload uploads on validation failure
            var items = await _unitOfWork.DatasetItems.GetAllAsync();
            model.UploadedItems = items.OrderByDescending(i => i.UploadedAt).ToList();
            model.LabelsList = GetPredefinedLabels();

            return View("Index", model);
        }

        private List<SelectListItem> GetPredefinedLabels()
        {
            return new List<SelectListItem>
            {
                new SelectListItem { Value = "Normal", Text = "Normal Scan" },
                new SelectListItem { Value = "Pneumonia", Text = "Pneumonia" },
                new SelectListItem { Value = "COVID-19", Text = "COVID-19" },
                new SelectListItem { Value = "Tuberculosis", Text = "Tuberculosis" },
                new SelectListItem { Value = "Bronchitis", Text = "Bronchitis" }
            };
        }
    }
}
