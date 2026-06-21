using System;
using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace ClinicAI.ViewModels.Case
{
    public class CaseDetailVM
    {
        public int Id { get; set; }
        public string PatientName { get; set; } = string.Empty;
        public string DoctorName { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public string Priority { get; set; } = string.Empty;
        public string PrimaryDiagnosis { get; set; } = string.Empty;
        public string? AdditionalInformation { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
