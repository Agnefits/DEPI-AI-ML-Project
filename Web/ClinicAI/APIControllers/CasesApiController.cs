using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;
using ClinicAI.DTOs.Cases;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class CasesApiController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;

        public CasesApiController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        [HttpGet]
        public async Task<IActionResult> GetCases()
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            IEnumerable<Case> cases;

            if (userRole == "Doctor")
            {
                cases = await _unitOfWork.Cases.GetCasesByDoctorIdAsync(loggedInUserId);
            }
            else if (userRole == "HospitalChef")
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
                if (chef == null || !chef.HospitalId.HasValue)
                {
                    return Ok(new List<CaseDto>());
                }
                cases = await _unitOfWork.Cases.GetCasesByHospitalIdAsync(chef.HospitalId.Value);
            }
            else // Admin/SuperAdmin/Radiologist
            {
                cases = await _unitOfWork.Cases.GetCasesWithDetailsAsync();
            }

            var dtos = cases.Select(c => new CaseDto
            {
                Id = c.Id,
                PatientId = c.PatientId,
                PatientName = c.Patient?.FullName ?? "Unknown",
                DoctorId = c.DoctorId,
                DoctorName = c.Doctor?.FullName ?? "Unassigned",
                Status = c.Status,
                Priority = c.Priority,
                AdditionalInformation = c.AdditionalInformation,
                CreatedAt = c.CreatedAt
            }).ToList();

            return Ok(dtos);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetCase(int id)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            var caseDetails = (await _unitOfWork.Cases.GetCasesWithDetailsAsync()).FirstOrDefault(c => c.Id == id);
            if (caseDetails == null)
            {
                return NotFound("Case not found.");
            }

            // Checks
            if (userRole == "Doctor" && caseDetails.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You do not own this clinical case.");
            }
            else if (userRole == "HospitalChef")
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
                var caseDoctor = caseDetails.Doctor;
                if (chef == null || !chef.HospitalId.HasValue || caseDoctor == null || caseDoctor.HospitalId != chef.HospitalId.Value)
                {
                    return Forbid("Access Denied: This case is not managed by a doctor in your hospital.");
                }
            }

            var dto = new CaseDto
            {
                Id = caseDetails.Id,
                PatientId = caseDetails.PatientId,
                PatientName = caseDetails.Patient?.FullName ?? "Unknown",
                DoctorId = caseDetails.DoctorId,
                DoctorName = caseDetails.Doctor?.FullName ?? "Unassigned",
                Status = caseDetails.Status,
                Priority = caseDetails.Priority,
                AdditionalInformation = caseDetails.AdditionalInformation,
                CreatedAt = caseDetails.CreatedAt
            };

            return Ok(dto);
        }

        [HttpPost]
        public async Task<IActionResult> CreateCase([FromBody] CaseCreateDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Invalid case payload.");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole == "HospitalChef")
            {
                return Forbid("Access Denied: Hospital Chefs cannot create clinical cases.");
            }

            // Verify patient exists and belongs to doctor
            var patient = await _unitOfWork.Patients.GetByIdAsync(dto.PatientId);
            if (patient == null)
            {
                return BadRequest("Patient does not exist.");
            }

            if (userRole == "Doctor" && patient.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You can only create cases for your own patients.");
            }

            var c = new Case
            {
                PatientId = dto.PatientId,
                DoctorId = patient.DoctorId,
                Status = "Pending",
                Priority = dto.Priority,
                AdditionalInformation = dto.AdditionalInformation,
                CreatedAt = DateTime.UtcNow
            };

            await _unitOfWork.Cases.AddAsync(c);
            await _unitOfWork.CompleteAsync();

            return CreatedAtAction(nameof(GetCase), new { id = c.Id }, new { id = c.Id, message = "Case record created successfully." });
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateCase(int id, [FromBody] CaseUpdateDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Invalid update payload.");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole == "HospitalChef")
            {
                return Forbid("Access Denied: Hospital Chefs cannot edit case records.");
            }

            var c = await _unitOfWork.Cases.GetByIdAsync(id);
            if (c == null)
            {
                return NotFound("Case not found.");
            }

            if (userRole == "Doctor" && c.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You cannot update cases of another doctor.");
            }

            c.Status = dto.Status;
            c.Priority = dto.Priority;
            c.AdditionalInformation = dto.AdditionalInformation;

            _unitOfWork.Cases.Update(c);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Case record updated successfully." });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteCase(int id)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole == "HospitalChef")
            {
                return Forbid("Access Denied: Hospital Chefs cannot delete case records.");
            }

            var c = await _unitOfWork.Cases.GetByIdAsync(id);
            if (c == null)
            {
                return NotFound("Case not found.");
            }

            if (userRole == "Doctor" && c.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You cannot delete cases of another doctor.");
            }

            _unitOfWork.Cases.Delete(c);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Case record deleted successfully." });
        }
    }
}
