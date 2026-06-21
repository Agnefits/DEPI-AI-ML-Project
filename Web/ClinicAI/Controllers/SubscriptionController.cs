using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using ClinicAI.Attributes;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("SuperAdmin", "Admin", "HospitalChef")]
    public class SubscriptionController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public SubscriptionController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        // List Subscriptions
        public async Task<IActionResult> Index()
        {
            var subscriptions = await _unitOfWork.Subscriptions.GetSubscriptionsWithHospitalAsync();

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            if (userRole == "HospitalChef" && int.TryParse(userIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                var chefHospitalId = chef?.HospitalId ?? 0;
                subscriptions = subscriptions.Where(s => s.HospitalId == chefHospitalId);
            }

            return View(subscriptions);
        }

        // Create (GET)
        [AuthorizedRoles("SuperAdmin")]
        public async Task<IActionResult> Create()
        {
            var hospitals = await _unitOfWork.Hospitals.GetAllAsync();
            ViewBag.HospitalsList = hospitals.Select(h => new SelectListItem
            {
                Value = h.Id.ToString(),
                Text = h.Name
            }).ToList();

            var subscription = new Subscription
            {
                StartDate = DateTime.Today,
                EndDate = DateTime.Today.AddYears(1)
            };

            return View(subscription);
        }

        // Create (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        [AuthorizedRoles("SuperAdmin")]
        public async Task<IActionResult> Create(Subscription model)
        {
            if (ModelState.IsValid)
            {
                model.CreatedAt = DateTime.UtcNow;
                await _unitOfWork.Subscriptions.AddAsync(model);
                await _unitOfWork.CompleteAsync();

                // Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1,
                    Action = "Create Subscription",
                    EntityName = "Subscription",
                    EntityId = model.Id,
                    OldValue = string.Empty,
                    NewValue = $"{model.PlanName} for Hospital ID {model.HospitalId}",
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }

            var hospitals = await _unitOfWork.Hospitals.GetAllAsync();
            ViewBag.HospitalsList = hospitals.Select(h => new SelectListItem
            {
                Value = h.Id.ToString(),
                Text = h.Name
            }).ToList();

            return View(model);
        }

        // Edit (GET)
        [AuthorizedRoles("SuperAdmin")]
        public async Task<IActionResult> Edit(int id)
        {
            var subscription = await _unitOfWork.Subscriptions.GetByIdAsync(id);
            if (subscription == null)
            {
                return NotFound();
            }

            var hospitals = await _unitOfWork.Hospitals.GetAllAsync();
            ViewBag.HospitalsList = hospitals.Select(h => new SelectListItem
            {
                Value = h.Id.ToString(),
                Text = h.Name,
                Selected = h.Id == subscription.HospitalId
            }).ToList();

            return View(subscription);
        }

        // Edit (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        [AuthorizedRoles("SuperAdmin")]
        public async Task<IActionResult> Edit(int id, Subscription model)
        {
            if (id != model.Id)
            {
                return NotFound();
            }

            if (ModelState.IsValid)
            {
                var subscription = await _unitOfWork.Subscriptions.GetByIdAsync(id);
                if (subscription == null)
                {
                    return NotFound();
                }

                var oldPlan = subscription.PlanName;

                subscription.HospitalId = model.HospitalId;
                subscription.PlanName = model.PlanName;
                subscription.StartDate = model.StartDate;
                subscription.EndDate = model.EndDate;
                subscription.Price = model.Price;
                subscription.Status = model.Status;

                _unitOfWork.Subscriptions.Update(subscription);
                await _unitOfWork.CompleteAsync();

                // Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1,
                    Action = "Edit Subscription",
                    EntityName = "Subscription",
                    EntityId = subscription.Id,
                    OldValue = oldPlan,
                    NewValue = subscription.PlanName,
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }

            var hospitals = await _unitOfWork.Hospitals.GetAllAsync();
            ViewBag.HospitalsList = hospitals.Select(h => new SelectListItem
            {
                Value = h.Id.ToString(),
                Text = h.Name,
                Selected = h.Id == model.HospitalId
            }).ToList();

            return View(model);
        }

        // Delete (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        [AuthorizedRoles("SuperAdmin")]
        public async Task<IActionResult> Delete(int id)
        {
            var subscription = await _unitOfWork.Subscriptions.GetByIdAsync(id);
            if (subscription != null)
            {
                _unitOfWork.Subscriptions.Delete(subscription);
                await _unitOfWork.CompleteAsync();

                // Audit Log
                var auditLog = new AuditLog
                {
                    UserId = 1,
                    Action = "Delete Subscription",
                    EntityName = "Subscription",
                    EntityId = id,
                    OldValue = subscription.PlanName,
                    NewValue = "Deleted",
                    CreatedAt = DateTime.UtcNow
                };
                await _unitOfWork.AuditLogs.AddAsync(auditLog);
                await _unitOfWork.CompleteAsync();
            }

            return RedirectToAction(nameof(Index));
        }
    }
}
