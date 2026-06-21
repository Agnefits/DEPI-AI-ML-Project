using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Attributes;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("SuperAdmin")]
    public class SmartModelController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public SmartModelController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        // List Smart Models
        public async Task<IActionResult> Index()
        {
            var models = await _unitOfWork.SmartModels.GetAllAsync();
            return View(models);
        }

        // Create (GET)
        public IActionResult Create()
        {
            return View(new SmartModel());
        }

        // Create (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(SmartModel model)
        {
            if (ModelState.IsValid)
            {
                model.CreatedAt = DateTime.UtcNow;
                await _unitOfWork.SmartModels.AddAsync(model);
                await _unitOfWork.CompleteAsync();

                // Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1,
                    Action = "Create Smart Model",
                    EntityName = "SmartModel",
                    EntityId = model.Id,
                    OldValue = string.Empty,
                    NewValue = $"{model.Name} ({model.Version})",
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }
            return View(model);
        }

        // Edit (GET)
        public async Task<IActionResult> Edit(int id)
        {
            var model = await _unitOfWork.SmartModels.GetByIdAsync(id);
            if (model == null)
            {
                return NotFound();
            }
            return View(model);
        }

        // Edit (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, SmartModel model)
        {
            if (id != model.Id)
            {
                return NotFound();
            }

            if (ModelState.IsValid)
            {
                var existingModel = await _unitOfWork.SmartModels.GetByIdAsync(id);
                if (existingModel == null)
                {
                    return NotFound();
                }

                var oldName = existingModel.Name;

                existingModel.Name = model.Name;
                existingModel.Version = model.Version;
                existingModel.Description = model.Description;
                existingModel.Accuracy = model.Accuracy;
                existingModel.IsActive = model.IsActive;

                _unitOfWork.SmartModels.Update(existingModel);
                await _unitOfWork.CompleteAsync();

                // Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1,
                    Action = "Edit Smart Model",
                    EntityName = "SmartModel",
                    EntityId = existingModel.Id,
                    OldValue = oldName,
                    NewValue = existingModel.Name,
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }
            return View(model);
        }

        // Toggle Active (POST)
        [HttpPost]
        public async Task<IActionResult> ToggleActive(int id)
        {
            var model = await _unitOfWork.SmartModels.GetByIdAsync(id);
            if (model != null)
            {
                model.IsActive = !model.IsActive;
                _unitOfWork.SmartModels.Update(model);
                await _unitOfWork.CompleteAsync();

                // Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1,
                    Action = "Toggle Smart Model Status",
                    EntityName = "SmartModel",
                    EntityId = model.Id,
                    OldValue = (!model.IsActive).ToString(),
                    NewValue = model.IsActive.ToString(),
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();
            }
            return RedirectToAction(nameof(Index));
        }
    }
}
