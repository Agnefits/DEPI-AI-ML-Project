using System.Security.Claims;
using ClinicAI.Models;

namespace ClinicAI.Services.Interfaces
{
    public interface IAuthService
    {
        string GenerateJwtToken(User user);
        string HashPassword(string password);
        bool VerifyPassword(string password, string hashedPassword);
        string GenerateRefreshToken();
        ClaimsPrincipal? GetPrincipalFromExpiredToken(string token);
    }
}
