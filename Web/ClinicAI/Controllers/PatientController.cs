using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using ClinicAI.Attributes;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;
using ClinicAI.ViewModels.Patient;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("Doctor", "Radiologist", "Admin", "SuperAdmin", "HospitalChef")]
    public class PatientController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public PatientController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        // List and Search Patients
        public async Task<IActionResult> Index(string searchString, string statusFilter)
        {
            var patients = await _unitOfWork.Patients.GetPatientsWithDoctorAsync();

            // Filter by role (Doctor vs Hospital Chef)
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                patients = patients.Where(p => p.DoctorId == currentDoctorId);
            }
            else if (userRole == "HospitalChef" && int.TryParse(userIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                if (chef != null && chef.HospitalId.HasValue)
                {
                    patients = patients.Where(p => p.Doctor != null && p.Doctor.HospitalId == chef.HospitalId.Value);
                }
                else
                {
                    patients = patients.Where(p => false);
                }
            }

            // Search filter by MRN or Full Name
            if (!string.IsNullOrEmpty(searchString))
            {
                patients = patients.Where(p => 
                    p.FullName.Contains(searchString, StringComparison.OrdinalIgnoreCase) || 
                    p.MedicalRecordNumber.Contains(searchString, StringComparison.OrdinalIgnoreCase)
                );
            }

            // Status filter (Active vs Archived)
            if (!string.IsNullOrEmpty(statusFilter))
            {
                if (statusFilter == "Archived")
                {
                    patients = patients.Where(p => p.IsArchived);
                }
                else if (statusFilter == "Active")
                {
                    patients = patients.Where(p => !p.IsArchived);
                }
            }

            var viewModels = patients.Select(p => new PatientVM
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

            ViewData["CurrentSearch"] = searchString;
            ViewData["CurrentStatusFilter"] = statusFilter;

            return View(viewModels);
        }

        // Edit Patient (GET)
        public async Task<IActionResult> Edit(int id)
        {
            var patient = await _unitOfWork.Patients.GetByIdAsync(id);
            if (patient == null)
            {
                return NotFound();
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            // Hospital Chef is not authorized to edit patients
            if (userRole == "HospitalChef")
            {
                return RedirectToAction("AccessDenied", "Account");
            }

            // Enforce ownership: Doctor can only access their own patients
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                if (patient.DoctorId != currentDoctorId)
                {
                    return RedirectToAction("AccessDenied", "Account");
                }
            }

            // Retrieve doctors to assign to patient
            var doctors = await _unitOfWork.Users.GetUsersByRoleAsync("Doctor");

            var viewModel = new PatientVM
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
                IsArchived = patient.IsArchived,
                CreatedAt = patient.CreatedAt,
                DoctorsList = doctors.Select(d => new SelectListItem
                {
                    Value = d.Id.ToString(),
                    Text = $"{d.FullName} ({d.Specialization ?? "General Practice"})"
                }).ToList()
            };

            return View(viewModel);
        }

        // Edit Patient (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, PatientVM model)
        {
            if (id != model.Id)
            {
                return NotFound();
            }

            var patient = await _unitOfWork.Patients.GetByIdAsync(id);
            if (patient == null)
            {
                return NotFound();
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            // Hospital Chef is not authorized to edit patients
            if (userRole == "HospitalChef")
            {
                return RedirectToAction("AccessDenied", "Account");
            }

            // Enforce ownership: Doctor can only edit their own patients
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                if (patient.DoctorId != currentDoctorId)
                {
                    return RedirectToAction("AccessDenied", "Account");
                }
            }

            if (ModelState.IsValid)
            {
                // Map updates
                patient.FullName = model.FullName;
                patient.Gender = model.Gender;
                patient.DOB = model.DOB;
                patient.Phone = model.Phone;
                patient.Address = model.Address;
                patient.BloodGroup = model.BloodGroup;
                patient.AdditionalInformation = model.AdditionalInformation;
                patient.DoctorId = model.DoctorId;
                patient.IsArchived = model.IsArchived;

                _unitOfWork.Patients.Update(patient);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }

            var doctors = await _unitOfWork.Users.GetUsersByRoleAsync("Doctor");
            model.DoctorsList = doctors.Select(d => new SelectListItem
            {
                Value = d.Id.ToString(),
                Text = d.FullName
            }).ToList();

            return View(model);
        }

        // Toggle Patient Archive Status (POST)
        [HttpPost]
        public async Task<IActionResult> ToggleArchive(int id)
        {
            var patient = await _unitOfWork.Patients.GetByIdAsync(id);
            if (patient != null)
            {
                var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
                var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                // Hospital Chef is not authorized to edit/archive patients
                if (userRole == "HospitalChef")
                {
                    return RedirectToAction("AccessDenied", "Account");
                }

                // Enforce ownership: Doctor can only archive/unarchive their own patients
                if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
                {
                    if (patient.DoctorId != currentDoctorId)
                    {
                        return RedirectToAction("AccessDenied", "Account");
                    }
                }

                patient.IsArchived = !patient.IsArchived;
                _unitOfWork.Patients.Update(patient);
                await _unitOfWork.CompleteAsync();
            }
            return RedirectToAction(nameof(Index));
        }
    }
}
