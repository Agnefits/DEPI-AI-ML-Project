using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.UnitOfWork;
using ClinicAI.DTOs.Subscriptions;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class SubscriptionsApiController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;

        public SubscriptionsApiController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        [HttpGet("my-hospital")]
        public async Task<IActionResult> GetMyHospitalSubscriptions()
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole != "HospitalChef" && userRole != "SuperAdmin")
            {
                return Forbid("Access Denied: Only Hospital Chefs can view hospital billing plans.");
            }

            var user = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
            if (user == null || !user.HospitalId.HasValue)
            {
                return BadRequest("User is not associated with any hospital.");
            }

            var subscriptions = await _unitOfWork.Subscriptions.GetSubscriptionsByHospitalIdAsync(user.HospitalId.Value);
            var dtos = subscriptions.Select(s => new SubscriptionDto
            {
                Id = s.Id,
                HospitalId = s.HospitalId,
                HospitalName = s.Hospital?.Name ?? "None",
                PlanName = s.PlanName,
                Price = s.Price,
                StartDate = s.StartDate,
                EndDate = s.EndDate,
                Status = s.Status
            }).ToList();

            return Ok(dtos);
        }
    }
}
