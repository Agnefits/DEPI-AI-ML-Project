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
using ClinicAI.DTOs.Patients;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class PatientsApiController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;

        public PatientsApiController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        [HttpGet]
        public async Task<IActionResult> GetPatients()
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            IEnumerable<Patient> patients;

            if (userRole == "Doctor")
            {
                patients = await _unitOfWork.Patients.GetPatientsByDoctorIdAsync(loggedInUserId);
            }
            else if (userRole == "HospitalChef")
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
                if (chef == null || !chef.HospitalId.HasValue)
                {
                    return Ok(new List<PatientDto>());
                }
                patients = await _unitOfWork.Patients.GetPatientsByHospitalIdAsync(chef.HospitalId.Value);
            }
            else // Admin & SuperAdmin
            {
                patients = await _unitOfWork.Patients.GetPatientsWithDoctorAsync();
            }

            var dtos = patients.Select(p => new PatientDto
            {
                Id = p.Id,
                MedicalRecordNumber = p.MedicalRecordNumber,
                FullName = p.FullName,
                Gender = p.Gender,
                DOB = p.DOB,
                Phone = p.Phone,
                Address = p.Address,
                BloodGroup = p.BloodGroup,
                AdditionalInformation = p.AdditionalInformation,
                DoctorId = p.DoctorId,
                DoctorName = p.Doctor?.FullName ?? "Unassigned",
                IsArchived = p.IsArchived,
                CreatedAt = p.CreatedAt
            }).ToList();

            return Ok(dtos);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetPatient(int id)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            var patient = await _unitOfWork.Patients.GetByIdAsync(id);
            if (patient == null)
            {
                return NotFound("Patient not found.");
            }

            // Eager load Doctor to get details
            var patientWithDoctor = (await _unitOfWork.Patients.GetPatientsWithDoctorAsync()).FirstOrDefault(p => p.Id == id);
            
            // Check authorization boundaries
            if (userRole == "Doctor" && patient.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You do not own this patient record.");
            }
            else if (userRole == "HospitalChef")
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(loggedInUserId);
                var patientDoctor = patientWithDoctor?.Doctor;
                if (chef == null || !chef.HospitalId.HasValue || patientDoctor == null || patientDoctor.HospitalId != chef.HospitalId.Value)
                {
                    return Forbid("Access Denied: This patient is not assigned to a doctor in your hospital.");
                }
            }

            var dto = new PatientDto
            {
                Id = patient.Id,
                MedicalRecordNumber = patient.MedicalRecordNumber,
                FullName = patient.FullName,
                Gender = patient.Gender,
                DOB = patient.DOB,
                Phone = patient.Phone,
                Address = patient.Address,
                BloodGroup = patient.BloodGroup,
                AdditionalInformation = patient.AdditionalInformation,
                DoctorId = patient.DoctorId,
                DoctorName = patientWithDoctor?.Doctor?.FullName ?? "Unassigned",
                IsArchived = patient.IsArchived,
                CreatedAt = patient.CreatedAt
            };

            return Ok(dto);
        }

        [HttpPost]
        public async Task<IActionResult> CreatePatient([FromBody] PatientCreateDto dto)
        {
            if (dto == null)
            {
                return BadRequest("Invalid patient payload.");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole == "HospitalChef")
            {
                return Forbid("Access Denied: Hospital Chefs cannot register patient profiles.");
            }

            // Assign doctor: if Doctor, assign to current doctor. If Admin, assign to chosen doctor.
            int doctorId = loggedInUserId;
            if (userRole == "Admin" || userRole == "SuperAdmin")
            {
                if (!dto.DoctorId.HasValue)
                {
                    return BadRequest("DoctorId is required for administrators creating patients.");
                }
                doctorId = dto.DoctorId.Value;
            }

            var patient = new Patient
            {
                MedicalRecordNumber = dto.MedicalRecordNumber,
                FullName = dto.FullName,
                Gender = dto.Gender,
                DOB = dto.DOB,
                Phone = dto.Phone,
                Address = dto.Address,
                BloodGroup = dto.BloodGroup,
                AdditionalInformation = dto.AdditionalInformation,
                DoctorId = doctorId,
                IsArchived = false,
                CreatedAt = DateTime.UtcNow
            };

            await _unitOfWork.Patients.AddAsync(patient);
            await _unitOfWork.CompleteAsync();

            return CreatedAtAction(nameof(GetPatient), new { id = patient.Id }, new { id = patient.Id, message = "Patient record created successfully." });
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdatePatient(int id, [FromBody] PatientUpdateDto dto)
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
                return Forbid("Access Denied: Hospital Chefs cannot modify patient profiles.");
            }

            var patient = await _unitOfWork.Patients.GetByIdAsync(id);
            if (patient == null)
            {
                return NotFound("Patient not found.");
            }

            if (userRole == "Doctor" && patient.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You cannot edit patients of another doctor.");
            }

            // Map updates
            patient.FullName = dto.FullName;
            patient.Gender = dto.Gender;
            patient.DOB = dto.DOB;
            patient.Phone = dto.Phone;
            patient.Address = dto.Address;
            patient.BloodGroup = dto.BloodGroup;
            patient.AdditionalInformation = dto.AdditionalInformation;
            patient.IsArchived = dto.IsArchived;

            if (userRole == "Admin" || userRole == "SuperAdmin")
            {
                patient.DoctorId = dto.DoctorId;
            }

            _unitOfWork.Patients.Update(patient);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Patient record updated successfully." });
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePatient(int id)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            if (userRole == "HospitalChef")
            {
                return Forbid("Access Denied: Hospital Chefs cannot delete or archive patients.");
            }

            var patient = await _unitOfWork.Patients.GetByIdAsync(id);
            if (patient == null)
            {
                return NotFound("Patient not found.");
            }

            if (userRole == "Doctor" && patient.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You cannot archive patients of another doctor.");
            }

            patient.IsArchived = true; // Soft delete/archive
            _unitOfWork.Patients.Update(patient);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Patient record archived successfully." });
        }
    }
}
