using System;

namespace ClinicAI.ViewModels.User
{
    public class UserVM
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string RoleName { get; set; } = string.Empty;
        public string? Specialization { get; set; }
        public string? ImageUrl { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public int? HospitalId { get; set; }
        public string? HospitalName { get; set; }
    }
}
