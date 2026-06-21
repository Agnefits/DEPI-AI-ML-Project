using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.DTOs.Profile;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ProfileController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuthService _authService;
        private readonly IFileService _fileService;

        public ProfileController(IUnitOfWork unitOfWork, IAuthService authService, IFileService fileService)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
            _fileService = fileService ?? throw new ArgumentNullException(nameof(fileService));
        }

        [HttpGet]
        public async Task<IActionResult> GetProfile()
        {
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
            {
                return Unauthorized();
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null)
            {
                return NotFound("User not found.");
            }

            var dto = new ProfileDto
            {
                Id = user.Id,
                Username = user.Username,
                FullName = user.FullName,
                Email = user.Email,
                Phone = user.Phone,
                Specialization = user.Specialization,
                ImageUrl = user.ImageUrl,
                RoleName = user.Role?.Name ?? "User",
                HospitalName = user.Hospital?.Name ?? "None"
            };

            return Ok(dto);
        }

        [HttpPut]
        public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Invalid profile data.");
            }

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
            {
                return Unauthorized();
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null)
            {
                return NotFound("User not found.");
            }

            user.FullName = dto.FullName;
            user.Phone = dto.Phone;
            user.Specialization = dto.Specialization;

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Profile updated successfully." });
        }

        [HttpPost("change-password")]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto)
        {
            if (dto == null || string.IsNullOrEmpty(dto.OldPassword) || string.IsNullOrEmpty(dto.NewPassword))
            {
                return BadRequest("Old and new passwords are required.");
            }

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
            {
                return Unauthorized();
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null)
            {
                return NotFound("User not found.");
            }

            if (!_authService.VerifyPassword(dto.OldPassword, user.PasswordHash))
            {
                return BadRequest("Incorrect current password.");
            }

            user.PasswordHash = _authService.HashPassword(dto.NewPassword);
            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Password updated successfully." });
        }

        [HttpPost("upload-avatar")]
        public async Task<IActionResult> UploadAvatar(IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest("Please attach a valid image file.");
            }

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
            {
                return Unauthorized();
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null)
            {
                return NotFound("User not found.");
            }

            // Remove old image if exists
            if (!string.IsNullOrEmpty(user.ImageUrl))
            {
                _fileService.DeleteFile(user.ImageUrl);
            }

            var savedPath = await _fileService.SaveFileAsync(file, "profiles");
            user.ImageUrl = savedPath;

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            return Ok(new { imageUrl = savedPath, message = "Avatar uploaded successfully." });
        }
    }
}
