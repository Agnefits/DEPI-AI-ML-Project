using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Attributes;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("SuperAdmin")]
    public class HospitalController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public HospitalController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        // List Hospitals
        public async Task<IActionResult> Index()
        {
            var hospitals = await _unitOfWork.Hospitals.GetAllAsync();
            return View(hospitals);
        }

        // Create (GET)
        public IActionResult Create()
        {
            return View(new Hospital());
        }

        // Create (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(Hospital hospital)
        {
            if (ModelState.IsValid)
            {
                hospital.CreatedAt = DateTime.UtcNow;
                await _unitOfWork.Hospitals.AddAsync(hospital);
                await _unitOfWork.CompleteAsync();

                // Save Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1, // System context default admin ID
                    Action = "Create Hospital",
                    EntityName = "Hospital",
                    EntityId = hospital.Id,
                    OldValue = string.Empty,
                    NewValue = hospital.Name,
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }
            return View(hospital);
        }

        // Edit (GET)
        public async Task<IActionResult> Edit(int id)
        {
            var hospital = await _unitOfWork.Hospitals.GetByIdAsync(id);
            if (hospital == null)
            {
                return NotFound();
            }
            return View(hospital);
        }

        // Edit (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, Hospital model)
        {
            if (id != model.Id)
            {
                return NotFound();
            }

            if (ModelState.IsValid)
            {
                var hospital = await _unitOfWork.Hospitals.GetByIdAsync(id);
                if (hospital == null)
                {
                    return NotFound();
                }

                var oldName = hospital.Name;

                hospital.Name = model.Name;
                hospital.Address = model.Address;
                hospital.Phone = model.Phone;
                hospital.Email = model.Email;
                hospital.IsActive = model.IsActive;

                _unitOfWork.Hospitals.Update(hospital);
                await _unitOfWork.CompleteAsync();

                // Save Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1,
                    Action = "Edit Hospital",
                    EntityName = "Hospital",
                    EntityId = hospital.Id,
                    OldValue = oldName,
                    NewValue = hospital.Name,
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }
            return View(model);
        }

        // Toggle Status (POST)
        [HttpPost]
        public async Task<IActionResult> ToggleActive(int id)
        {
            var hospital = await _unitOfWork.Hospitals.GetByIdAsync(id);
            if (hospital != null)
            {
                hospital.IsActive = !hospital.IsActive;
                _unitOfWork.Hospitals.Update(hospital);
                await _unitOfWork.CompleteAsync();

                // Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1,
                    Action = "Toggle Hospital Status",
                    EntityName = "Hospital",
                    EntityId = hospital.Id,
                    OldValue = (!hospital.IsActive).ToString(),
                    NewValue = hospital.IsActive.ToString(),
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();
            }
            return RedirectToAction(nameof(Index));
        }
    }
}
