using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using ClinicAI.Attributes;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;
using ClinicAI.ViewModels.Case;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("Doctor", "Radiologist", "Admin", "SuperAdmin", "HospitalChef")]
    public class CaseController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public CaseController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        // List and Filter Cases
        public async Task<IActionResult> Index(string diseaseFilter, int? doctorFilter, DateTime? dateFilter)
        {
            var allCases = await _unitOfWork.Cases.GetCasesWithDetailsAsync();
            var filteredCases = allCases.AsEnumerable();

            // 0. Enforce Doctor and Hospital Chef RBAC checks
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            
            User? chef = null;
            if (userRole == "HospitalChef" && int.TryParse(userIdStr, out var chefId))
            {
                chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                if (chef != null && chef.HospitalId.HasValue)
                {
                    filteredCases = filteredCases.Where(c => c.Doctor != null && c.Doctor.HospitalId == chef.HospitalId.Value);
                }
                else
                {
                    filteredCases = filteredCases.Where(c => false);
                }
            }
            else if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                filteredCases = filteredCases.Where(c => c.DoctorId == currentDoctorId);
                // Override doctor filter to be the logged-in doctor
                doctorFilter = currentDoctorId;
            }

            // 1. Filter by diagnosed disease
            if (!string.IsNullOrEmpty(diseaseFilter))
            {
                filteredCases = filteredCases.Where(c => c.Diagnoses != null && 
                    c.Diagnoses.Any(d => d.DiagnosisName.Equals(diseaseFilter, StringComparison.OrdinalIgnoreCase)));
            }

            // 2. Filter by doctor (for Admins/SuperAdmins/Radiologists/Chefs)
            if (doctorFilter.HasValue && doctorFilter.Value > 0)
            {
                filteredCases = filteredCases.Where(c => c.DoctorId == doctorFilter.Value);
            }

            // 3. Filter by date
            if (dateFilter.HasValue)
            {
                filteredCases = filteredCases.Where(c => c.CreatedAt.Date == dateFilter.Value.Date);
            }

            // Map list to view models
            var caseList = filteredCases.Select(c => new CaseDetailVM
            {
                Id = c.Id,
                PatientName = c.Patient?.FullName ?? "Unknown Patient",
                DoctorName = c.Doctor?.FullName ?? "Unassigned Doctor",
                Status = c.Status,
                Priority = c.Priority,
                PrimaryDiagnosis = c.Diagnoses?.FirstOrDefault()?.DiagnosisName ?? "Pending Diagnosis",
                AdditionalInformation = c.AdditionalInformation,
                CreatedAt = c.CreatedAt
            }).ToList();

            // Fetch doctor users for filtering dropdown
            var doctors = await _unitOfWork.Users.GetUsersByRoleAsync("Doctor");
            
            // If the user is a doctor, restrict the dropdown to them only
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var loggedInDocId))
            {
                doctors = doctors.Where(d => d.Id == loggedInDocId);
            }
            else if (userRole == "HospitalChef" && chef != null && chef.HospitalId.HasValue)
            {
                doctors = doctors.Where(d => d.HospitalId == chef.HospitalId.Value);
            }

            // Fetch unique diagnoses names for filtering dropdown
            var allDiagnoses = await _unitOfWork.Diagnoses.GetAllAsync();
            var uniqueDiseases = allDiagnoses.Select(d => d.DiagnosisName).Distinct().ToList();
            if (!uniqueDiseases.Any())
            {
                // Fallback default options for empty db
                uniqueDiseases.AddRange(new[] { "Pneumonia", "COVID-19", "Tuberculosis", "Bronchitis", "Normal Scan" });
            }

            var viewModel = new CaseFilterVM
            {
                SelectedDisease = diseaseFilter,
                SelectedDoctorId = doctorFilter,
                SelectedDate = dateFilter,
                DoctorsList = doctors.Select(d => new SelectListItem
                {
                    Value = d.Id.ToString(),
                    Text = d.FullName,
                    Selected = d.Id == doctorFilter
                }).ToList(),
                DiseasesList = uniqueDiseases.Select(d => new SelectListItem
                {
                    Value = d,
                    Text = d,
                    Selected = d.Equals(diseaseFilter, StringComparison.OrdinalIgnoreCase)
                }).ToList(),
                CasesList = caseList
            };

            return View(viewModel);
        }
    }
}
