using System;
using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace ClinicAI.ViewModels.Patient
{
    public class PatientVM
    {
        public int Id { get; set; }
        public string MedicalRecordNumber { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Gender { get; set; } = string.Empty;
        public DateTime DOB { get; set; }
        public string? Phone { get; set; }
        public string? Address { get; set; }
        public string? BloodGroup { get; set; }
        public string? AdditionalInformation { get; set; }
        public int DoctorId { get; set; }
        public string? DoctorName { get; set; }
        public bool IsArchived { get; set; }
        public DateTime CreatedAt { get; set; }

        // Drop-down lists for doctor assignment
        public List<SelectListItem> DoctorsList { get; set; } = new();
    }
}
