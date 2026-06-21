using System;

namespace ClinicAI.DTOs.Cases
{
    public class CaseDto
    {
        public int Id { get; set; }
        public int PatientId { get; set; }
        public string PatientName { get; set; } = string.Empty;
        public int DoctorId { get; set; }
        public string DoctorName { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public string Priority { get; set; } = string.Empty;
        public string? AdditionalInformation { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
