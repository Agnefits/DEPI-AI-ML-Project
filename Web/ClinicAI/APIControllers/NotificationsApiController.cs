using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.UnitOfWork;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class NotificationsApiController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;

        public NotificationsApiController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        [HttpGet]
        public async Task<IActionResult> GetNotifications()
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            var notifications = await _unitOfWork.Notifications.FindAsync(n => n.UserId == loggedInUserId && !n.IsRead);
            var sortedList = notifications.OrderByDescending(n => n.CreatedAt).Select(n => new
            {
                id = n.Id,
                title = n.Title,
                message = n.Message,
                createdAt = n.CreatedAt
            }).ToList();

            return Ok(sortedList);
        }

        [HttpPost("{id}/read")]
        public async Task<IActionResult> MarkAsRead(int id)
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            var notification = await _unitOfWork.Notifications.GetByIdAsync(id);
            if (notification == null || notification.UserId != loggedInUserId)
            {
                return NotFound("Notification not found.");
            }

            notification.IsRead = true;
            _unitOfWork.Notifications.Update(notification);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Notification marked as read." });
        }
    }
}
