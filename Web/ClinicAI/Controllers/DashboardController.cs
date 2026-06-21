using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.UnitOfWork;
using ClinicAI.ViewModels.Dashboard;
using ClinicAI.Attributes;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("Doctor", "Radiologist", "Admin", "SuperAdmin", "HospitalChef")]
    public class DashboardController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public DashboardController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        public async Task<IActionResult> Index()
        {
            var viewModel = new DashboardVM();

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            int? currentHospitalId = null;
            bool isDoctor = false;
            bool isChef = false;
            int currentUserId = 0;

            if (int.TryParse(userIdStr, out currentUserId))
            {
                var currentUser = await _unitOfWork.Users.GetByIdAsync(currentUserId);
                if (currentUser != null)
                {
                    currentHospitalId = currentUser.HospitalId;
                    if (userRole == "Doctor")
                    {
                        isDoctor = true;
                    }
                    else if (userRole == "HospitalChef")
                    {
                        isChef = true;
                    }
                }
            }

            // 1. Users count (Active Staff)
            var allUsers = await _unitOfWork.Users.GetAllAsync();
            if (isChef && currentHospitalId.HasValue)
            {
                viewModel.UsersCount = allUsers.Count(u => u.HospitalId == currentHospitalId.Value && u.IsActive);
            }
            else if (isDoctor)
            {
                viewModel.UsersCount = allUsers.Count(u => u.HospitalId == currentHospitalId && u.IsActive);
            }
            else
            {
                viewModel.UsersCount = allUsers.Count();
            }

            // 2. Patients count
            var allPatients = await _unitOfWork.Patients.GetAllAsync();
            if (isChef && currentHospitalId.HasValue)
            {
                var doctors = await _unitOfWork.Users.GetUsersByRoleAsync("Doctor");
                var docIdsInHospital = doctors.Where(d => d.HospitalId == currentHospitalId.Value).Select(d => d.Id).ToHashSet();
                allPatients = allPatients.Where(p => docIdsInHospital.Contains(p.DoctorId));
            }
            else if (isDoctor)
            {
                allPatients = allPatients.Where(p => p.DoctorId == currentUserId);
            }
            viewModel.PatientsCount = allPatients.Count();

            // 3. Cases count
            var allCases = await _unitOfWork.Cases.GetAllAsync();
            if (isChef && currentHospitalId.HasValue)
            {
                var doctors = await _unitOfWork.Users.GetUsersByRoleAsync("Doctor");
                var docIdsInHospital = doctors.Where(d => d.HospitalId == currentHospitalId.Value).Select(d => d.Id).ToHashSet();
                allCases = allCases.Where(c => docIdsInHospital.Contains(c.DoctorId));
            }
            else if (isDoctor)
            {
                allCases = allCases.Where(c => c.DoctorId == currentUserId);
            }
            viewModel.CasesCount = allCases.Count();

            // 4. Diagnoses count
            var allDiagnoses = await _unitOfWork.Diagnoses.GetAllAsync();
            if (isChef && currentHospitalId.HasValue)
            {
                var caseIds = allCases.Select(c => c.Id).ToHashSet();
                allDiagnoses = allDiagnoses.Where(d => caseIds.Contains(d.CaseId));
            }
            else if (isDoctor)
            {
                var caseIds = allCases.Select(c => c.Id).ToHashSet();
                allDiagnoses = allDiagnoses.Where(d => caseIds.Contains(d.CaseId));
            }
            viewModel.DiagnosesCount = allDiagnoses.Count();

            // 5. AI Analyses count
            var allAiAnalyses = await _unitOfWork.AIAnalyses.GetAllAsync();
            if (isChef && currentHospitalId.HasValue)
            {
                var caseIds = allCases.Select(c => c.Id).ToHashSet();
                allAiAnalyses = allAiAnalyses.Where(a => caseIds.Contains(a.CaseId));
            }
            else if (isDoctor)
            {
                var caseIds = allCases.Select(c => c.Id).ToHashSet();
                allAiAnalyses = allAiAnalyses.Where(a => caseIds.Contains(a.CaseId));
            }
            viewModel.AIUsageCount = allAiAnalyses.Count();

            // Compute Daily Cases (Last 7 days)
            var today = DateTime.Today;
            for (int i = 6; i >= 0; i--)
            {
                var date = today.AddDays(-i);
                viewModel.DailyLabels.Add(date.ToString("ddd (MM/dd)"));
                
                int count = allCases.Count(c => c.CreatedAt.Date == date);
                viewModel.DailyData.Add(count);
            }

            // Compute Monthly Cases (Last 6 months)
            for (int i = 5; i >= 0; i--)
            {
                var monthDate = today.AddMonths(-i);
                viewModel.MonthlyLabels.Add(monthDate.ToString("MMM yyyy"));
                
                int count = allCases.Count(c => c.CreatedAt.Year == monthDate.Year && c.CreatedAt.Month == monthDate.Month);
                viewModel.MonthlyData.Add(count);
            }

            // Compute Most Common Diseases (Top 5)
            var commonDiseases = allDiagnoses
                .GroupBy(d => d.DiagnosisName)
                .Select(g => new { Disease = g.Key, Count = g.Count() })
                .OrderByDescending(x => x.Count)
                .Take(5)
                .ToList();

            foreach (var disease in commonDiseases)
            {
                viewModel.DiseaseLabels.Add(disease.Disease);
                viewModel.DiseaseData.Add(disease.Count);
            }

            // Pre-seed some default chart display details if database is blank
            if (!viewModel.DiseaseLabels.Any())
            {
                viewModel.DiseaseLabels.AddRange(new[] { "Pneumonia", "COVID-19", "Tuberculosis", "Bronchitis", "Normal Scan" });
                viewModel.DiseaseData.AddRange(new[] { 14, 9, 5, 3, 28 });
            }

            return View(viewModel);
        }
    }
}
