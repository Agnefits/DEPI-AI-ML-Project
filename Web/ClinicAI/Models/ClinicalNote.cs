using System;

namespace ClinicAI.Models
{
    public class ClinicalNote
    {
        public int Id { get; set; }
        public int CaseId { get; set; }
        public string Subjective { get; set; } = string.Empty;
        public string Objective { get; set; } = string.Empty;
        public string Assessment { get; set; } = string.Empty;
        public string Plan { get; set; } = string.Empty;
        public string? AdditionalInformation  { get; set; }
        public bool GeneratedByAI { get; set; }
        public bool ApprovedByDoctor { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation property
        public Case? Case { get; set; }
    }
}
