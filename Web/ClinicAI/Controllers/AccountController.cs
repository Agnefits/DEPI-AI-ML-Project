using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.UnitOfWork;
using ClinicAI.Services.Interfaces;
using ClinicAI.ViewModels.Account;

namespace ClinicAI.Controllers
{
    public class AccountController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuthService _authService;
        private readonly IEmailService _emailService;

        public AccountController(IUnitOfWork unitOfWork, IAuthService authService, IEmailService emailService)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
            _emailService = emailService ?? throw new ArgumentNullException(nameof(emailService));
        }

        [HttpGet]
        public IActionResult Login(string? returnUrl = null)
        {
            // If already authenticated, redirect to Dashboard
            if (User.Identity != null && User.Identity.IsAuthenticated)
            {
                return RedirectToAction("Index", "Dashboard");
            }

            var model = new LoginVM { ReturnUrl = returnUrl };
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginVM model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(model.Username);
            if (user == null || !_authService.VerifyPassword(model.Password, user.PasswordHash))
            {
                ModelState.AddModelError(string.Empty, "Invalid username or password.");
                return View(model);
            }

            if (!user.IsActive)
            {
                ModelState.AddModelError(string.Empty, "Your account has been deactivated. Please contact the administrator.");
                return View(model);
            }

            // Generate JWT Token
            var token = _authService.GenerateJwtToken(user);

            // Set token in HTTP-only Cookie
            var cookieOptions = new CookieOptions
            {
                HttpOnly = true,
                Expires = DateTime.UtcNow.AddMinutes(60),
                SameSite = SameSiteMode.Lax,
                Secure = false // allow HTTP for development ease, or set dynamically
            };

            Response.Cookies.Append("jwt", token, cookieOptions);

            // Log login audit log entry
            var auditLog = new Models.AuditLog
            {
                UserId = user.Id,
                Action = "User Login",
                EntityName = "User",
                EntityId = user.Id,
                OldValue = string.Empty,
                NewValue = "Logged in successfully",
                CreatedAt = DateTime.UtcNow
            };
            await _unitOfWork.AuditLogs.AddAsync(auditLog);
            await _unitOfWork.CompleteAsync();

            if (!string.IsNullOrEmpty(model.ReturnUrl) && Url.IsLocalUrl(model.ReturnUrl))
            {
                return Redirect(model.ReturnUrl);
            }

            return RedirectToAction("Index", "Dashboard");
        }

        [HttpGet]
        [HttpPost]
        public IActionResult Logout()
        {
            Response.Cookies.Delete("jwt");
            return RedirectToAction(nameof(Login));
        }

        [HttpGet]
        public IActionResult AccessDenied()
        {
            return View();
        }

        [HttpGet]
        public IActionResult ForgotPassword()
        {
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ForgotPassword(string email)
        {
            if (string.IsNullOrEmpty(email))
            {
                ModelState.AddModelError(string.Empty, "Email address is required.");
                return View();
            }

            var user = await _unitOfWork.Users.GetByEmailAsync(email);
            if (user == null)
            {
                TempData["ResetEmail"] = email;
                return RedirectToAction(nameof(VerifyOtp));
            }

            var random = new Random();
            var otp = random.Next(100000, 999999).ToString();

            user.PasswordResetOtp = otp;
            user.PasswordResetOtpExpiry = DateTime.UtcNow.AddMinutes(15);

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

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
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, "Error sending verification email: " + ex.Message);
                return View();
            }

            TempData["ResetEmail"] = email;
            return RedirectToAction(nameof(VerifyOtp));
        }

        [HttpGet]
        public IActionResult VerifyOtp()
        {
            var email = TempData["ResetEmail"] as string;
            if (string.IsNullOrEmpty(email))
            {
                return RedirectToAction(nameof(ForgotPassword));
            }

            TempData.Keep("ResetEmail");
            ViewBag.Email = email;
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> VerifyOtp(string email, string otpCode)
        {
            if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(otpCode))
            {
                ModelState.AddModelError(string.Empty, "Email and verification code are required.");
                ViewBag.Email = email;
                return View();
            }

            var user = await _unitOfWork.Users.GetByEmailAsync(email);
            if (user == null || user.PasswordResetOtp != otpCode || user.PasswordResetOtpExpiry <= DateTime.UtcNow)
            {
                ModelState.AddModelError(string.Empty, "Invalid or expired verification code.");
                ViewBag.Email = email;
                return View();
            }

            TempData["ResetEmail"] = email;
            TempData["ResetOtp"] = otpCode;
            return RedirectToAction(nameof(ResetPassword));
        }

        [HttpGet]
        public IActionResult ResetPassword()
        {
            var email = TempData["ResetEmail"] as string;
            var otp = TempData["ResetOtp"] as string;

            if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(otp))
            {
                return RedirectToAction(nameof(ForgotPassword));
            }

            TempData.Keep("ResetEmail");
            TempData.Keep("ResetOtp");
            ViewBag.Email = email;
            ViewBag.Otp = otp;
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ResetPassword(string email, string otpCode, string newPassword, string confirmPassword)
        {
            if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(otpCode) || string.IsNullOrEmpty(newPassword))
            {
                ModelState.AddModelError(string.Empty, "All fields are required.");
                ViewBag.Email = email;
                ViewBag.Otp = otpCode;
                return View();
            }

            if (newPassword != confirmPassword)
            {
                ModelState.AddModelError(string.Empty, "Passwords do not match.");
                ViewBag.Email = email;
                ViewBag.Otp = otpCode;
                return View();
            }

            var user = await _unitOfWork.Users.GetByEmailAsync(email);
            if (user == null || user.PasswordResetOtp != otpCode || user.PasswordResetOtpExpiry <= DateTime.UtcNow)
            {
                ModelState.AddModelError(string.Empty, "Invalid or expired verification session.");
                ViewBag.Email = email;
                ViewBag.Otp = otpCode;
                return View();
            }

            user.PasswordHash = _authService.HashPassword(newPassword);
            user.PasswordResetOtp = null;
            user.PasswordResetOtpExpiry = null;

            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            TempData["SuccessMessage"] = "Your password has been successfully reset! You can now log in.";
            return RedirectToAction(nameof(Login));
        }
    }
}
