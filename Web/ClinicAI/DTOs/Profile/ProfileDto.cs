namespace ClinicAI.DTOs.Profile
{
    public class ProfileDto
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string? Specialization { get; set; }
        public string? ImageUrl { get; set; }
        public string RoleName { get; set; } = string.Empty;
        public string HospitalName { get; set; } = string.Empty;
    }
}
