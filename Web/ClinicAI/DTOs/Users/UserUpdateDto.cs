namespace ClinicAI.DTOs.Users
{
    public class UserUpdateDto
    {
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string? Specialization { get; set; }
        public string? Password { get; set; } // Optional password change
        public bool IsActive { get; set; }
    }
}
