using System;
using System.Collections.Generic;

namespace ClinicAI.Models
{
    public class Patient
    {
        public int Id { get; set; }
        public string MedicalRecordNumber { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Gender { get; set; } = string.Empty;
        public DateTime DOB { get; set; }
        public string? Phone { get; set; }
        public string? Address { get; set; }
        public string? BloodGroup { get; set; }
        public string? AdditionalInformation  { get; set; }
        public int DoctorId { get; set; }
        public bool IsArchived { get; set; } = false;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public User? Doctor { get; set; }
        public ICollection<Case>? Cases { get; set; }
    }
}
