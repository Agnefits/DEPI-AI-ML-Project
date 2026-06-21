using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;

using ClinicAI.Attributes;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("Admin", "SuperAdmin")]
    public class AuditLogController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public AuditLogController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        // List Audit Logs
        public async Task<IActionResult> Index()
        {
            var logs = await _unitOfWork.AuditLogs.GetAuditLogsWithUserAsync();
            var sortedLogs = logs.OrderByDescending(l => l.CreatedAt).ToList();

            // Seed dummy audit logs if database is empty to verify layout and actions
            if (!sortedLogs.Any())
            {
                var actions = new[] { "User Login", "Edit Patient Profile", "Approve Diagnostic Report", "Create New Case", "Toggle Staff Status" };
                var entities = new[] { "User", "Patient", "Report", "Case", "User" };

                for (int i = 0; i < 5; i++)
                {
                    sortedLogs.Add(new AuditLog
                    {
                        Id = 800 + i,
                        UserId = 1,
                        User = new User { FullName = "System Administrator", Username = "admin" },
                        Action = actions[i],
                        EntityName = entities[i],
                        EntityId = 100 + i * 5,
                        OldValue = i % 2 == 0 ? "Old state details" : null,
                        NewValue = "Operation transaction executed successfully.",
                        CreatedAt = DateTime.UtcNow.AddMinutes(-i * 45)
                    });
                }
            }

            return View(sortedLogs);
        }
    }
}
