using System;

namespace ClinicAI.Models
{
    public class MedicalImage
    {
        public int Id { get; set; }
        public int CaseId { get; set; }
        public string FilePath { get; set; } = string.Empty;
        public string ImageType { get; set; } = string.Empty; // e.g. XRay, MRI, CT
        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;

        // Navigation property
        public Case? Case { get; set; }
    }
}
