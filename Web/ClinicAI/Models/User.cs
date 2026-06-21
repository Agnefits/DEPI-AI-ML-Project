using System;

namespace ClinicAI.Models
{
    public class User
    {
        public int Id { get; set; }
        public string Username { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string PasswordHash { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public string? ImageUrl { get; set; }
        public string? Specialization { get; set; }
        public int RoleId { get; set; }
        public int? HospitalId { get; set; }
        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Refresh Token & OTP password recovery fields
        public string? RefreshToken { get; set; }
        public DateTime? RefreshTokenExpiryTime { get; set; }
        public string? PasswordResetOtp { get; set; }
        public DateTime? PasswordResetOtpExpiry { get; set; }

        // Navigation properties
        public Role? Role { get; set; }
        public Hospital? Hospital { get; set; }
    }
}
