using System;
using System.Collections.Generic;

namespace ClinicAI.Models
{
    public class Case
    {
        public int Id { get; set; }
        public int PatientId { get; set; }
        public int DoctorId { get; set; }
        public string Status { get; set; } = string.Empty;
        public string Priority { get; set; } = string.Empty;
        public string? AdditionalInformation  { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public Patient? Patient { get; set; }
        public User? Doctor { get; set; }

        public ICollection<CaseSymptom>? CaseSymptoms { get; set; }
        public ICollection<MedicalImage>? MedicalImages { get; set; }
        public ICollection<AIAnalysis>? AIAnalyses { get; set; }
        public ICollection<ClinicalNote>? ClinicalNotes { get; set; }
        public ICollection<Diagnosis>? Diagnoses { get; set; }
        public ICollection<Report>? Reports { get; set; }
    }
}
