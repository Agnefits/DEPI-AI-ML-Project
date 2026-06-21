namespace ClinicAI.DTOs.Profile
{
    public class UpdateProfileDto
    {
        public string FullName { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string? Specialization { get; set; }
    }
}
