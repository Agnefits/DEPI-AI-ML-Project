using System;
using System.Collections.Generic;

namespace ClinicAI.ViewModels.AiMonitoring
{
    public class RecentAnalysisVM
    {
        public int AnalysisId { get; set; }
        public int CaseId { get; set; }
        public string PatientName { get; set; } = string.Empty;
        public string ModelVersion { get; set; } = string.Empty;
        public double Confidence { get; set; }
        public double ProcessingTime { get; set; }
        public DateTime CreatedAt { get; set; }
        public string Findings { get; set; } = string.Empty;
        public bool IsSuccess { get; set; }
    }
}
