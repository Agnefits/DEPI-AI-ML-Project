using System.Collections.Generic;

namespace ClinicAI.ViewModels.Report
{
    public class ReportEditVM
    {
        public int Id { get; set; }
        public int CaseId { get; set; }
        public string PatientName { get; set; } = string.Empty;
        public string ReportContent { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty; // e.g. Pending, Generated, Approved/Signed
        public string? ReportPdf { get; set; }
        public string? AdditionalInformation { get; set; }

        // AI Analysis details
        public double AIConfidence { get; set; }
        public string AIModelVersion { get; set; } = string.Empty;
        public List<string> AIFindings { get; set; } = new List<string>();
        public string? MedicalImagePath { get; set; }

        // Diagnostic approval details
        public int? DiagnosisId { get; set; }
        public string DiagnosisName { get; set; } = string.Empty;
        public string ICD10Code { get; set; } = string.Empty;
        public bool ApproveDiagnosis { get; set; }
    }
}
