using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Attributes;
using ClinicAI.Models;
using ClinicAI.UnitOfWork;
using ClinicAI.ViewModels.Report;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("Radiologist", "Doctor", "HospitalChef")]
    public class ReportController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;

        public ReportController(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        // List Reports
        public async Task<IActionResult> Index()
        {
            var reports = await _unitOfWork.Reports.GetReportsWithDetailsAsync();

            // Enforce Doctor and Hospital Chef RBAC checks
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                reports = reports.Where(r => r.Case != null && r.Case.DoctorId == currentDoctorId);
            }
            else if (userRole == "HospitalChef" && int.TryParse(userIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                if (chef != null && chef.HospitalId.HasValue)
                {
                    reports = reports.Where(r => r.Case != null && r.Case.Doctor != null && r.Case.Doctor.HospitalId == chef.HospitalId.Value);
                }
                else
                {
                    reports = reports.Where(r => false);
                }
            }

            var viewModelList = reports.Select(r => new ReportEditVM
            {
                Id = r.Id,
                CaseId = r.CaseId,
                PatientName = r.Case?.Patient?.FullName ?? "Unknown Patient",
                ReportContent = r.ReportContent,
                Status = r.Status,
                ReportPdf = r.ReportPdf,
                AdditionalInformation = r.AdditionalInformation
            }).ToList();

            return View(viewModelList);
        }

        // Edit Report (GET)
        public async Task<IActionResult> Edit(int id)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            if (userRole == "HospitalChef")
            {
                return RedirectToAction("AccessDenied", "Account");
            }

            var report = await _unitOfWork.Reports.GetReportWithDetailsAsync(id);
            if (report == null)
            {
                return NotFound();
            }

            // Enforce ownership: Doctor can only edit reports of their cases
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                if (report.Case == null || report.Case.DoctorId != currentDoctorId)
                {
                    return RedirectToAction("AccessDenied", "Account");
                }
            }

            var relatedCase = report.Case;
            var ai = relatedCase?.AIAnalyses?.OrderByDescending(a => a.CreatedAt).FirstOrDefault();
            
            var findingsList = new System.Collections.Generic.List<string>();
            double aiConfidence = 0;
            string modelVersion = "N/A";
            if (ai != null)
            {
                aiConfidence = ai.Confidence;
                modelVersion = ai.ModelVersion;
                if (ai.Findings != null)
                {
                    findingsList = ai.Findings.Select(f => $"{f.Finding} ({Math.Round(f.Confidence * 100, 1)}%)").ToList();
                }
            }

            var imagePath = relatedCase?.MedicalImages?.FirstOrDefault()?.FilePath;
            var diag = relatedCase?.Diagnoses?.FirstOrDefault();

            var viewModel = new ReportEditVM
            {
                Id = report.Id,
                CaseId = report.CaseId,
                PatientName = relatedCase?.Patient?.FullName ?? "Unknown Patient",
                ReportContent = report.ReportContent,
                Status = report.Status,
                ReportPdf = report.ReportPdf,
                AdditionalInformation = report.AdditionalInformation,
                
                // AI Insights
                AIConfidence = aiConfidence,
                AIModelVersion = modelVersion,
                AIFindings = findingsList,
                MedicalImagePath = imagePath,
                
                // Diagnosis Details
                DiagnosisId = diag?.Id,
                DiagnosisName = diag?.DiagnosisName ?? string.Empty,
                ICD10Code = diag?.ICD10Code ?? string.Empty,
                ApproveDiagnosis = diag?.IsFinal ?? false
            };

            return View(viewModel);
        }

        // Edit Report (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, ReportEditVM model)
        {
            if (id != model.Id)
            {
                return NotFound();
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            if (userRole == "HospitalChef")
            {
                return RedirectToAction("AccessDenied", "Account");
            }

            if (ModelState.IsValid)
            {
                var report = await _unitOfWork.Reports.GetByIdAsync(id);
                if (report == null)
                {
                    return NotFound();
                }

                // Enforce ownership: Doctor can only edit reports of their cases
                var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
                {
                    var reportWithDetails = await _unitOfWork.Reports.GetReportWithDetailsAsync(id);
                    if (reportWithDetails == null || reportWithDetails.Case == null || reportWithDetails.Case.DoctorId != currentDoctorId)
                    {
                        return RedirectToAction("AccessDenied", "Account");
                    }
                }

                var oldVal = report.ReportContent;
                
                // Update report properties
                report.ReportContent = model.ReportContent;
                report.AdditionalInformation = model.AdditionalInformation;
                
                // Determine user context for audit logging
                int userId = 1;
                var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                if (int.TryParse(userIdClaim, out var parsedId))
                {
                    userId = parsedId;
                }

                if (model.ApproveDiagnosis)
                {
                    report.Status = "Approved/Signed";
                    
                    // Manage Diagnosis approval
                    var diagnoses = await _unitOfWork.Diagnoses.FindAsync(d => d.CaseId == report.CaseId);
                    var diag = diagnoses.FirstOrDefault();
                    if (diag == null)
                    {
                        diag = new Diagnosis
                        {
                            CaseId = report.CaseId,
                            DiagnosisName = model.DiagnosisName,
                            ICD10Code = model.ICD10Code,
                            Confidence = 1.0,
                            IsFinal = true
                        };
                        await _unitOfWork.Diagnoses.AddAsync(diag);
                    }
                    else
                    {
                        diag.DiagnosisName = model.DiagnosisName;
                        diag.ICD10Code = model.ICD10Code;
                        diag.IsFinal = true;
                        diag.Confidence = 1.0;
                        _unitOfWork.Diagnoses.Update(diag);
                    }

                    // Update Case Status to Completed
                    var relatedCase = await _unitOfWork.Cases.GetByIdAsync(report.CaseId);
                    if (relatedCase != null)
                    {
                        relatedCase.Status = "Completed";
                        _unitOfWork.Cases.Update(relatedCase);
                    }

                    // Audit Log
                    var auditLog = new AuditLog
                    {
                        UserId = userId,
                        Action = "Approve Diagnosis and Report",
                        EntityName = "Report",
                        EntityId = report.Id,
                        OldValue = "Unsigned",
                        NewValue = $"Approved - Diagnosis: {model.DiagnosisName} ({model.ICD10Code})",
                        CreatedAt = DateTime.UtcNow
                    };
                    await _unitOfWork.AuditLogs.AddAsync(auditLog);
                    await _unitOfWork.CompleteAsync();
                }
                else
                {
                    // Reset signed status if modified but not checked as approved
                    if (report.Status == "Approved/Signed" || report.Status == "Signed")
                    {
                        report.Status = "Pending Re-Approval";
                    }

                    // Update diagnosis without final flag if it exists
                    var diagnoses = await _unitOfWork.Diagnoses.FindAsync(d => d.CaseId == report.CaseId);
                    var diag = diagnoses.FirstOrDefault();
                    if (diag != null)
                    {
                        diag.DiagnosisName = model.DiagnosisName;
                        diag.ICD10Code = model.ICD10Code;
                        diag.IsFinal = false;
                        _unitOfWork.Diagnoses.Update(diag);
                    }

                    // Audit Log
                    var auditLog = new AuditLog
                    {
                        UserId = userId,
                        Action = "Edit Report",
                        EntityName = "Report",
                        EntityId = report.Id,
                        OldValue = oldVal,
                        NewValue = report.ReportContent,
                        CreatedAt = DateTime.UtcNow
                    };
                    await _unitOfWork.AuditLogs.AddAsync(auditLog);
                    await _unitOfWork.CompleteAsync();
                }

                _unitOfWork.Reports.Update(report);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }

            return View(model);
        }

        // Approve / Sign Report (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Approve(int id)
        {
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            if (userRole == "HospitalChef")
            {
                return RedirectToAction("AccessDenied", "Account");
            }

            var report = await _unitOfWork.Reports.GetReportWithDetailsAsync(id);
            if (report == null)
            {
                return NotFound();
            }

            // Enforce ownership: Doctor can only sign off reports of their cases
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userRole == "Doctor" && int.TryParse(userIdStr, out var currentDoctorId))
            {
                if (report.Case == null || report.Case.DoctorId != currentDoctorId)
                {
                    return RedirectToAction("AccessDenied", "Account");
                }
            }

            var oldStatus = report.Status;
            report.Status = "Approved/Signed";
            
            _unitOfWork.Reports.Update(report);
            await _unitOfWork.CompleteAsync();

            int userId = 1;
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (int.TryParse(userIdClaim, out var parsedId))
            {
                userId = parsedId;
            }

            // Save Audit Log entry
            var auditLog = new AuditLog
            {
                UserId = userId,
                Action = "Approve Report",
                EntityName = "Report",
                EntityId = report.Id,
                OldValue = oldStatus,
                NewValue = "Approved/Signed",
                CreatedAt = DateTime.UtcNow
            };
            await _unitOfWork.AuditLogs.AddAsync(auditLog);
            await _unitOfWork.CompleteAsync();

            return RedirectToAction(nameof(Index));
        }
    }
}
