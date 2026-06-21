using System;
using System.IO;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Attributes;
using ClinicAI.Models;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;
using ClinicAI.ViewModels.User;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("SuperAdmin", "Admin", "Doctor", "Radiologist", "HospitalChef")]
    public class ProfileController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuthService _authService;
        private readonly IFileService _fileService;

        public ProfileController(IUnitOfWork unitOfWork, IAuthService authService, IFileService fileService)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
            _fileService = fileService ?? throw new ArgumentNullException(nameof(fileService));
        }

        [HttpGet]
        public async Task<IActionResult> Index()
        {
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null)
            {
                return NotFound();
            }

            var viewModel = new UserFormVM
            {
                Id = user.Id,
                Username = user.Username,
                FullName = user.FullName,
                Email = user.Email,
                Phone = user.Phone,
                Specialization = user.Specialization,
                RoleId = user.RoleId,
                HospitalId = user.HospitalId,
                IsActive = user.IsActive,
                ImageUrl = user.ImageUrl
            };

            ViewBag.RoleName = user.Role?.Name ?? "User";
            ViewBag.HospitalName = user.Hospital?.Name ?? "None";

            return View(viewModel);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Index(UserFormVM model)
        {
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username) || username != model.Username)
            {
                return RedirectToAction("AccessDenied", "Account");
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null)
            {
                return NotFound();
            }

            if (ModelState.IsValid)
            {
                user.FullName = model.FullName;
                user.Email = model.Email;
                user.Phone = model.Phone;
                user.Specialization = model.Specialization;

                // Handle image upload
                if (model.ImageFile != null)
                {
                    if (!string.IsNullOrEmpty(user.ImageUrl))
                    {
                        _fileService.DeleteFile(user.ImageUrl);
                    }
                    user.ImageUrl = await _fileService.SaveFileAsync(model.ImageFile, "profiles");
                }

                _unitOfWork.Users.Update(user);
                await _unitOfWork.CompleteAsync();

                // Re-issue JWT cookie so nav avatar updates without re-login
                var newToken = _authService.GenerateJwtToken(user);
                Response.Cookies.Append("jwt", newToken, new Microsoft.AspNetCore.Http.CookieOptions
                {
                    HttpOnly = true,
                    Expires = DateTime.UtcNow.AddMinutes(120),
                    SameSite = Microsoft.AspNetCore.Http.SameSiteMode.Lax,
                    Secure = false
                });

                TempData["ProfileSuccess"] = "Profile updated successfully!";
                return RedirectToAction(nameof(Index));
            }

            ViewBag.RoleName = user.Role?.Name ?? "User";
            ViewBag.HospitalName = user.Hospital?.Name ?? "None";
            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ChangePassword(string oldPassword, string newPassword, string confirmPassword)
        {
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
            {
                return RedirectToAction("Login", "Account");
            }

            var user = await _unitOfWork.Users.GetByUsernameAsync(username);
            if (user == null)
            {
                return NotFound();
            }

            if (string.IsNullOrEmpty(oldPassword) || string.IsNullOrEmpty(newPassword))
            {
                TempData["PasswordError"] = "Both current and new passwords are required.";
                return RedirectToAction(nameof(Index));
            }

            if (newPassword != confirmPassword)
            {
                TempData["PasswordError"] = "New passwords do not match.";
                return RedirectToAction(nameof(Index));
            }

            if (!_authService.VerifyPassword(oldPassword, user.PasswordHash))
            {
                TempData["PasswordError"] = "Incorrect current password.";
                return RedirectToAction(nameof(Index));
            }

            user.PasswordHash = _authService.HashPassword(newPassword);
            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();

            TempData["PasswordSuccess"] = "Password updated successfully!";
            return RedirectToAction(nameof(Index));
        }
    }
}
