using System;
using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace ClinicAI.ViewModels.Case
{
    public class CaseFilterVM
    {
        public string? SelectedDisease { get; set; }
        public int? SelectedDoctorId { get; set; }
        public DateTime? SelectedDate { get; set; }

        public List<SelectListItem> DoctorsList { get; set; } = new();
        public List<SelectListItem> DiseasesList { get; set; } = new();
        public List<CaseDetailVM> CasesList { get; set; } = new();
    }
}
