using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Models;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;
using ClinicAI.DTOs.Users;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class UsersApiController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuthService _authService;

        public UsersApiController(IUnitOfWork unitOfWork, IAuthService authService)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
        }

        [HttpGet("doctors")]
        public async Task<IActionResult> GetDoctors()
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole != "HospitalChef" && userRole != "Admin" && userRole != "SuperAdmin")
            {
                return Forbid();
            }

            var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
            if (chef == null || !chef.HospitalId.HasValue)
            {
                return BadRequest("Chef is not associated with a hospital.");
            }

            var doctors = await _unitOfWork.Users.GetDoctorsByHospitalIdAsync(chef.HospitalId.Value);
            var dtos = doctors.Select(u => new UserDto
            {
                Id = u.Id,
                Username = u.Username,
                FullName = u.FullName,
                Email = u.Email,
                Phone = u.Phone,
                Specialization = u.Specialization,
                ImageUrl = u.ImageUrl,
                RoleName = u.Role?.Name ?? "Doctor",
                HospitalName = u.Hospital?.Name ?? "None",
                IsActive = u.IsActive,
                CreatedAt = u.CreatedAt
            }).ToList();

            return Ok(dtos);
        }

        [HttpPost("doctors")]
        public async Task<IActionResult> CreateDoctor([FromBody] UserCreateDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Invalid payload.");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole != "HospitalChef")
            {
                return Forbid("Access Denied: Only Hospital Chefs can create doctors for their hospital.");
            }

            var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
            if (chef == null || !chef.HospitalId.HasValue)
            {
                return BadRequest("Chef has no assigned hospital.");
            }

            // Check if username or email exists
            var existingUser = await _unitOfWork.Users.GetByUsernameAsync(dto.Username);
            if (existingUser != null)
            {
                return BadRequest("Username is already taken.");
            }

            existingUser = await _unitOfWork.Users.GetByEmailAsync(dto.Email);
            if (existingUser != null)
            {
                return BadRequest("Email is already registered.");
            }

            var matchedRoles = await _unitOfWork.Roles.FindAsync(r => r.Name == "Doctor");
            var doctorRole = matchedRoles.FirstOrDefault();
            if (doctorRole == null)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, "Doctor role is not configured in database.");
            }

            var newDoctor = new User
            {
                Username = dto.Username,
                FullName = dto.FullName,
                Email = dto.Email,
                PasswordHash = _authService.HashPassword(dto.Password),
                Phone = dto.Phone,
                Specialization = dto.Specialization,
                RoleId = doctorRole.Id,
                HospitalId = chef.HospitalId.Value,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            await _unitOfWork.Users.AddAsync(newDoctor);
            await _unitOfWork.CompleteAsync();

            return Ok(new { id = newDoctor.Id, message = "Doctor registered successfully." });
        }

        [HttpPut("doctors/{id}")]
        public async Task<IActionResult> UpdateDoctor(int id, [FromBody] UserUpdateDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Invalid payload.");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole != "HospitalChef")
            {
                return Forbid("Access Denied: Only Hospital Chefs can manage hospital staff.");
            }

            var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
            if (chef == null || !chef.HospitalId.HasValue)
            {
                return BadRequest("Chef has no assigned hospital.");
            }

            var doctor = await _unitOfWork.Users.GetByIdAsync(id);
            if (doctor == null || doctor.HospitalId != chef.HospitalId.Value)
            {
                return NotFound("Doctor not found in your hospital.");
            }

            // Map edits
            doctor.FullName = dto.FullName;
            doctor.Email = dto.Email;
            doctor.Phone = dto.Phone;
            doctor.Specialization = dto.Specialization;
            doctor.IsActive = dto.IsActive;

            if (!string.IsNullOrEmpty(dto.Password))
            {
                doctor.PasswordHash = _authService.HashPassword(dto.Password);
            }

            _unitOfWork.Users.Update(doctor);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Doctor profile updated successfully." });
        }

        [HttpDelete("doctors/{id}")]
        public async Task<IActionResult> DeleteDoctor(int id)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole != "HospitalChef")
            {
                return Forbid("Access Denied: Only Hospital Chefs can deactivate doctors.");
            }

            var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
            if (chef == null || !chef.HospitalId.HasValue)
            {
                return BadRequest("Chef has no assigned hospital.");
            }

            var doctor = await _unitOfWork.Users.GetByIdAsync(id);
            if (doctor == null || doctor.HospitalId != chef.HospitalId.Value)
            {
                return NotFound("Doctor not found in your hospital.");
            }

            doctor.IsActive = false; // Soft delete/deactivate
            _unitOfWork.Users.Update(doctor);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Doctor account deactivated successfully." });
        }
    }
}
