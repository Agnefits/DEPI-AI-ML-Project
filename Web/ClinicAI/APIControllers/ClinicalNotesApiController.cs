using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;
using ClinicAI.DTOs.ClinicalNotes;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ClinicalNotesApiController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;

        public ClinicalNotesApiController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        [HttpGet("case/{caseId}")]
        public async Task<IActionResult> GetNotesForCase(int caseId)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            var c = await _unitOfWork.Cases.GetByIdAsync(caseId);
            if (c == null)
            {
                return NotFound("Case not found.");
            }

            // Checks
            if (userRole == "Doctor" && c.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You do not own this clinical case.");
            }
            else if (userRole == "HospitalChef")
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
                var caseDoctor = await _unitOfWork.Users.GetByIdAsync(c.DoctorId);
                if (chef == null || !chef.HospitalId.HasValue || caseDoctor == null || caseDoctor.HospitalId != chef.HospitalId.Value)
                {
                    return Forbid("Access Denied: Case does not belong to a doctor in your hospital.");
                }
            }

            var notes = await _unitOfWork.ClinicalNotes.FindAsync(n => n.CaseId == caseId);
            var dtos = notes.Select(n => new ClinicalNoteDto
            {
                Id = n.Id,
                CaseId = n.CaseId,
                Subjective = n.Subjective,
                Objective = n.Objective,
                Assessment = n.Assessment,
                Plan = n.Plan,
                AdditionalInformation = n.AdditionalInformation,
                GeneratedByAI = n.GeneratedByAI,
                ApprovedByDoctor = n.ApprovedByDoctor,
                CreatedAt = n.CreatedAt
            }).ToList();

            return Ok(dtos);
        }

        [HttpPost]
        public async Task<IActionResult> CreateNote([FromBody] ClinicalNoteCreateDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Invalid note payload.");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole != "Doctor" && userRole != "SuperAdmin" && userRole != "Admin")
            {
                return Forbid("Access Denied: Only doctors can write clinical SOAP notes.");
            }

            var c = await _unitOfWork.Cases.GetByIdAsync(dto.CaseId);
            if (c == null)
            {
                return BadRequest("Case does not exist.");
            }

            if (userRole == "Doctor" && c.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You cannot add notes to cases of other doctors.");
            }

            var note = new ClinicalNote
            {
                CaseId = dto.CaseId,
                Subjective = dto.Subjective,
                Objective = dto.Objective,
                Assessment = dto.Assessment,
                Plan = dto.Plan,
                AdditionalInformation = dto.AdditionalInformation,
                GeneratedByAI = false,
                ApprovedByDoctor = false,
                CreatedAt = DateTime.UtcNow
            };

            await _unitOfWork.ClinicalNotes.AddAsync(note);
            await _unitOfWork.CompleteAsync();

            return Ok(new { id = note.Id, message = "SOAP clinical note created successfully." });
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateNote(int id, [FromBody] ClinicalNoteUpdateDto dto)
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

            var note = await _unitOfWork.ClinicalNotes.GetByIdAsync(id);
            if (note == null)
            {
                return NotFound("Clinical note not found.");
            }

            var c = await _unitOfWork.Cases.GetByIdAsync(note.CaseId);
            if (c == null)
            {
                return NotFound("Associated case not found.");
            }

            if (userRole == "Doctor" && c.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You cannot modify notes of other doctors.");
            }

            note.Subjective = dto.Subjective;
            note.Objective = dto.Objective;
            note.Assessment = dto.Assessment;
            note.Plan = dto.Plan;
            note.AdditionalInformation = dto.AdditionalInformation;

            _unitOfWork.ClinicalNotes.Update(note);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Clinical note updated successfully." });
        }

        [HttpPost("{id}/approve")]
        public async Task<IActionResult> ApproveNote(int id)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            var note = await _unitOfWork.ClinicalNotes.GetByIdAsync(id);
            if (note == null)
            {
                return NotFound("Clinical note not found.");
            }

            var c = await _unitOfWork.Cases.GetByIdAsync(note.CaseId);
            if (c == null)
            {
                return NotFound("Associated case not found.");
            }

            if (userRole != "Doctor" || c.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: Only the case doctor can sign off and approve this clinical note.");
            }

            note.ApprovedByDoctor = true;
            _unitOfWork.ClinicalNotes.Update(note);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Clinical note signed and approved successfully." });
        }
    }
}
