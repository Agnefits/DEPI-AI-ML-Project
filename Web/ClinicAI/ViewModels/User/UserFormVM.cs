using System.Collections.Generic;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace ClinicAI.ViewModels.User
{
    public class UserFormVM
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Password { get; set; } // Optional on Edit
        public string? Phone { get; set; }
        public string? Specialization { get; set; }
        public int RoleId { get; set; }
        public bool IsActive { get; set; } = true;
        public string? ImageUrl { get; set; }

        public IFormFile? ImageFile { get; set; }
        public int? HospitalId { get; set; }
 
        // Role drop-down list items
        public List<SelectListItem> RolesList { get; set; } = new();

        // Hospital drop-down list items
        public List<SelectListItem> HospitalsList { get; set; } = new();
    }
}
