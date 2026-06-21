using System;

namespace ClinicAI.DTOs.Patients
{
    public class PatientCreateDto
    {
        public string MedicalRecordNumber { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Gender { get; set; } = string.Empty;
        public DateTime DOB { get; set; }
        public string? Phone { get; set; }
        public string? Address { get; set; }
        public string? BloodGroup { get; set; }
        public string? AdditionalInformation { get; set; }
        public int? DoctorId { get; set; } // Can be assigned on create, or auto-assigned
    }
}
