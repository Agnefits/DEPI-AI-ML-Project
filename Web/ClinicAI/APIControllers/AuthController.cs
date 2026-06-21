using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Models;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;
using ClinicAI.DTOs.Auth;
using Microsoft.AspNetCore.Http;

namespace ClinicAI.APIControllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuthService _authService;
        private readonly IEmailService _emailService;

        public AuthController(IUnitOfWork unitOfWork, IAuthService authService, IEmailService emailService)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
            _emailService = emailService ?? throw new ArgumentNullException(nameof(emailService));
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            if (dto == null)
                return BadRequest("Invalid registration payload.");

            if (string.IsNullOrEmpty(dto.Username) || string.IsNullOrEmpty(dto.Email) || string.IsNullOrEmpty(dto.Password) || string.IsNullOrEmpty(dto.FullName))
                return BadRequest("Username, FullName, Email, and Password are required.");

            var existingUser = await _unitOfWork.Users.GetByUsernameAsync(dto.Username);
            if (existingUser != null)
                return BadRequest("Username is already taken.");

            existingUser = await _unitOfWork.Users.GetByEmailAsync(dto.Email);
            if (existingUser != null)
                return BadRequest("Email is already registered.");

            var roleName = string.IsNullOrEmpty(dto.Role) ? "Doctor" : dto.Role;
            var matchedRoles = await _unitOfWork.Roles.FindAsync(r => r.Name == roleName);
            var role = matchedRoles.FirstOrDefault();
            if (role == null)
            {
                return BadRequest($"Role '{roleName}' is not defined in the system. Available roles are Doctor, Radiologist, Admin, HospitalChef.");
            }

            var user = new User
            {
                Username = dto.Username,
                FullName = dto.FullName,
                Email = dto.Email,
                PasswordHash = _authService.HashPassword(dto.Password),
                Phone = dto.Phone,
                RoleId = role.Id,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            await _unitOfWork.Users.AddAsync(user);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Registration successful." });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginDto dto)
        {
            if (dto == null)
                return BadRequest("Invalid login payload.");

            if (string.IsNullOrEmpty(dto.Username) || string.IsNullOrEmpty(dto.Password))
                return BadRequest("Username and password are required.");

            var user = await _unitOfWork.Users.GetByUsernameAsync(dto.Username);
            if (user == null || !_authService.VerifyPassword(dto.Password, user.PasswordHash))
            {
                return Unauthorized("Invalid credentials.");
            }

            if (!user.IsActive)
            {
                return StatusCode(StatusCodes.Status403Forbidden, "Account is disabled. Please contact your system administrator.");
            }

            var accessToken = _authService.GenerateJwtToken(user);
            var refreshToken = _authService.GenerateRefreshToken();

            user.RefreshToken = refreshToken;
            user.RefreshTokenExpiryTime = DateTime.UtcNow.AddDays(7);

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            return Ok(new TokenResponseDto
            {
                AccessToken = accessToken,
                RefreshToken = refreshToken,
                Role = user.Role?.Name ?? "User",
                Username = user.Username
            });
        }

        [HttpPost("refresh")]
        public async Task<IActionResult> Refresh([FromBody] RefreshTokenDto dto)
        {
            if (dto == null)
                return BadRequest("Invalid request payload.");

            var principal = _authService.GetPrincipalFromExpiredToken(dto.AccessToken);
            if (principal == null)
            {
                return BadRequest("Invalid access token.");
            }

            var username = principal.Identity?.Name;
            if (string.IsNullOrEmpty(username))
            {
                return BadRequest("Invalid token claims.");
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null || user.RefreshToken != dto.RefreshToken || user.RefreshTokenExpiryTime <= DateTime.UtcNow)
            {
                return BadRequest("Invalid or expired refresh token.");
            }

            var newAccessToken = _authService.GenerateJwtToken(user);
            var newRefreshToken = _authService.GenerateRefreshToken();

            user.RefreshToken = newRefreshToken;
            user.RefreshTokenExpiryTime = DateTime.UtcNow.AddDays(7);

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            return Ok(new TokenResponseDto
            {
                AccessToken = newAccessToken,
                RefreshToken = newRefreshToken,
                Role = user.Role?.Name ?? "User",
                Username = user.Username
            });
        }

        [HttpPost("revoke")]
        public async Task<IActionResult> Revoke()
        {
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
            {
                return Unauthorized();
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null)
            {
                return BadRequest("User not found.");
            }

            user.RefreshToken = null;
            user.RefreshTokenExpiryTime = null;

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Token successfully revoked." });
        }

        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordDto dto)
        {
            if (dto == null || string.IsNullOrEmpty(dto.Email))
            {
                return BadRequest("Email address is required.");
            }

            var user = await _unitOfWork.Users.GetByEmailAsync(dto.Email);
            if (user == null)
            {
                // Return Ok to prevent user enumeration
                return Ok(new { message = "If the email is registered in our system, you will receive an OTP code shortly." });
            }

            // Generate a 6-digit OTP code
            var random = new Random();
            var otp = random.Next(100000, 999999).ToString();

            user.PasswordResetOtp = otp;
            user.PasswordResetOtpExpiry = DateTime.UtcNow.AddMinutes(15);

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            // Send email
            var emailSubject = "ClinicAI - Password Reset Verification Code";
            var emailBody = $@"
                <div style='font-family: Arial, sans-serif; padding: 20px; background-color: #f3f4f6;'>
                    <div style='max-width: 600px; margin: 0 auto; background-color: #ffffff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05);'>
                        <h2 style='color: #4f46e5; margin-bottom: 20px;'>Password Reset Request</h2>
                        <p>We received a request to reset your password for your ClinicAI account.</p>
                        <p>Your one-time verification code (OTP) is:</p>
                        <div style='text-align: center; margin: 30px 0;'>
                            <span style='font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #4f46e5; background-color: #e0e7ff; padding: 15px 30px; border-radius: 8px; border: 1px solid #c7d2fe;'>{otp}</span>
                        </div>
                        <p style='color: #ef4444;'><strong>This code will expire in 15 minutes.</strong></p>
                        <p>If you did not request a password reset, please ignore this email or contact support.</p>
                    </div>
                </div>";

            try
            {
                await _emailService.SendEmailAsync(user.Email, emailSubject, emailBody);
            }
            catch (Exception)
            {
                // Log exception in a real app, let's gracefully return Ok
            }

            return Ok(new { message = "If the email is registered in our system, you will receive an OTP code shortly." });
        }

        [HttpPost("verify-otp")]
        public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpDto dto)
        {
            if (dto == null || string.IsNullOrEmpty(dto.Email) || string.IsNullOrEmpty(dto.OtpCode))
            {
                return BadRequest("Email and OTP code are required.");
            }

            var user = await _unitOfWork.Users.GetByEmailAsync(dto.Email);
            if (user == null || user.PasswordResetOtp != dto.OtpCode || user.PasswordResetOtpExpiry <= DateTime.UtcNow)
            {
                return BadRequest("Invalid or expired verification code.");
            }

            return Ok(new { message = "Code verified successfully. You can now reset your password." });
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordDto dto)
        {
            if (dto == null || string.IsNullOrEmpty(dto.Email) || string.IsNullOrEmpty(dto.OtpCode) || string.IsNullOrEmpty(dto.NewPassword))
            {
                return BadRequest("Email, OTP code, and new password are required.");
            }

            var user = await _unitOfWork.Users.GetByEmailAsync(dto.Email);
            if (user == null || user.PasswordResetOtp != dto.OtpCode || user.PasswordResetOtpExpiry <= DateTime.UtcNow)
            {
                return BadRequest("Invalid or expired verification code.");
            }

            // Reset password
            user.PasswordHash = _authService.HashPassword(dto.NewPassword);
            user.PasswordResetOtp = null;
            user.PasswordResetOtpExpiry = null;

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            return Ok(new { message = "Password has been reset successfully." });
        }
    }
}
