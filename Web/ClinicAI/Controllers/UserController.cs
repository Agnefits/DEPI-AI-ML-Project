using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using ClinicAI.Models;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;
using ClinicAI.ViewModels.User;
using ClinicAI.Attributes;

namespace ClinicAI.Controllers
{
    [AuthorizedRoles("Admin", "SuperAdmin", "HospitalChef")]
    public class UserController : Controller
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IAuthService _authService;
        private readonly IFileService _fileService;

        public UserController(IUnitOfWork unitOfWork, IAuthService authService, IFileService fileService)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _authService = authService ?? throw new ArgumentNullException(nameof(authService));
            _fileService = fileService ?? throw new ArgumentNullException(nameof(fileService));
        }

        // List Users
        public async Task<IActionResult> Index()
        {
            var users = await _unitOfWork.Users.GetUsersWithRolesAsync();
            
            var loggedInRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
            var loggedInUserIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            if (loggedInRole == "Admin")
            {
                users = users.Where(u => u.Role?.Name != "SuperAdmin");
            }
            else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                int chefHospitalId = chef?.HospitalId ?? 0;
                users = users.Where(u => u.Role?.Name == "Doctor" && u.HospitalId == chefHospitalId);
            }

            var viewModelList = users.Select(u => new UserVM
            {
                Id = u.Id,
                Username = u.Username,
                FullName = u.FullName,
                Email = u.Email,
                Phone = u.Phone,
                RoleName = u.Role?.Name ?? "User",
                Specialization = u.Specialization,
                ImageUrl = u.ImageUrl,
                IsActive = u.IsActive,
                CreatedAt = u.CreatedAt,
                HospitalId = u.HospitalId,
                HospitalName = u.Hospital?.Name ?? "None"
            }).ToList();

            return View(viewModelList);
        }

        // Create User (GET)
        public async Task<IActionResult> Create()
        {
            var loggedInRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
            var loggedInUserIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var roles = await _unitOfWork.Roles.GetAllAsync();
            var hospitals = await _unitOfWork.Hospitals.GetAllAsync();

            int? forcedHospitalId = null;
            int? forcedRoleId = null;

            if (loggedInRole == "Admin")
            {
                roles = roles.Where(r => r.Name != "SuperAdmin");
            }
            else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                forcedHospitalId = chef?.HospitalId;
                
                var doctorRole = roles.FirstOrDefault(r => r.Name == "Doctor");
                forcedRoleId = doctorRole?.Id;

                roles = roles.Where(r => r.Name == "Doctor");
                hospitals = hospitals.Where(h => h.Id == forcedHospitalId);
            }

            var viewModel = new UserFormVM
            {
                HospitalId = forcedHospitalId,
                RoleId = forcedRoleId ?? 0,
                RolesList = roles.Select(r => new SelectListItem
                {
                    Value = r.Id.ToString(),
                    Text = r.Name
                }).ToList(),
                HospitalsList = hospitals.Select(h => new SelectListItem
                {
                    Value = h.Id.ToString(),
                    Text = h.Name
                }).ToList()
            };

            return View(viewModel);
        }

        // Create User (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(UserFormVM model)
        {
            var loggedInRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
            var loggedInUserIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            if (string.IsNullOrEmpty(model.Username) || string.IsNullOrEmpty(model.Email) || string.IsNullOrEmpty(model.Password) || string.IsNullOrEmpty(model.FullName))
            {
                ModelState.AddModelError(string.Empty, "Username, FullName, Email, and Password are required fields.");
            }

            var existingUser = await _unitOfWork.Users.GetByUsernameAsync(model.Username);
            if (existingUser != null)
            {
                ModelState.AddModelError("Username", "Username is already taken.");
            }

            // Security constraints verification
            if (loggedInRole == "Admin")
            {
                var targetRole = await _unitOfWork.Roles.GetByIdAsync(model.RoleId);
                if (targetRole != null && targetRole.Name == "SuperAdmin")
                {
                    ModelState.AddModelError("RoleId", "Administrators are not permitted to register Super Admin accounts.");
                }
            }
            else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                var chefHospitalId = chef?.HospitalId;
                
                var doctorRole = (await _unitOfWork.Roles.GetAllAsync()).FirstOrDefault(r => r.Name == "Doctor");
                
                // Force properties to prevent tampering
                model.RoleId = doctorRole?.Id ?? model.RoleId;
                model.HospitalId = chefHospitalId;
            }

            if (ModelState.IsValid)
            {
                string? imageUrl = null;
                if (model.ImageFile != null)
                {
                    imageUrl = await _fileService.SaveFileAsync(model.ImageFile, "profiles");
                }

                var user = new User
                {
                    Username = model.Username,
                    FullName = model.FullName,
                    Email = model.Email,
                    PasswordHash = _authService.HashPassword(model.Password!),
                    Phone = model.Phone,
                    Specialization = model.Specialization,
                    RoleId = model.RoleId,
                    HospitalId = model.HospitalId,
                    IsActive = model.IsActive,
                    ImageUrl = imageUrl,
                    CreatedAt = DateTime.UtcNow
                };

                await _unitOfWork.Users.AddAsync(user);
                await _unitOfWork.CompleteAsync();

                return RedirectToAction(nameof(Index));
            }

            // Reload Lists if validations failed
            var roles = await _unitOfWork.Roles.GetAllAsync();
            var hospitals = await _unitOfWork.Hospitals.GetAllAsync();
            
            if (loggedInRole == "Admin")
            {
                roles = roles.Where(r => r.Name != "SuperAdmin");
            }
            else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId2))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId2);
                var chefHospitalId = chef?.HospitalId;
                roles = roles.Where(r => r.Name == "Doctor");
                hospitals = hospitals.Where(h => h.Id == chefHospitalId);
            }

            model.RolesList = roles.Select(r => new SelectListItem
            {
                Value = r.Id.ToString(),
                Text = r.Name
            }).ToList();
            
            model.HospitalsList = hospitals.Select(h => new SelectListItem
            {
                Value = h.Id.ToString(),
                Text = h.Name
            }).ToList();

            return View(model);
        }

        // Edit User (GET)
        public async Task<IActionResult> Edit(int id)
        {
            var user = await _unitOfWork.Users.GetByIdAsync(id);
            if (user == null)
            {
                return NotFound();
            }

            var loggedInRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
            var loggedInUserIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            // Load roles & hospitals
            var roles = await _unitOfWork.Roles.GetAllAsync();
            var hospitals = await _unitOfWork.Hospitals.GetAllAsync();

            var targetRole = roles.FirstOrDefault(r => r.Id == user.RoleId);

            // Authorization Checks
            if (loggedInRole == "Admin")
            {
                if (targetRole != null && targetRole.Name == "SuperAdmin")
                {
                    return RedirectToAction("AccessDenied", "Account");
                }
                
                roles = roles.Where(r => r.Name != "SuperAdmin");
            }
            else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                var chefHospitalId = chef?.HospitalId;

                if (targetRole == null || targetRole.Name != "Doctor" || user.HospitalId != chefHospitalId)
                {
                    return RedirectToAction("AccessDenied", "Account");
                }

                roles = roles.Where(r => r.Name == "Doctor");
                hospitals = hospitals.Where(h => h.Id == chefHospitalId);
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
                ImageUrl = user.ImageUrl,
                RolesList = roles.Select(r => new SelectListItem
                {
                    Value = r.Id.ToString(),
                    Text = r.Name,
                    Selected = r.Id == user.RoleId
                }).ToList(),
                HospitalsList = hospitals.Select(h => new SelectListItem
                {
                    Value = h.Id.ToString(),
                    Text = h.Name,
                    Selected = h.Id == user.HospitalId
                }).ToList()
            };

            return View(viewModel);
        }

        // Edit User (POST)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, UserFormVM model)
        {
            if (id != model.Id)
            {
                return NotFound();
            }

            var user = await _unitOfWork.Users.GetByIdAsync(id);
            if (user == null)
            {
                return NotFound();
            }

            var loggedInRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
            var loggedInUserIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var roles = await _unitOfWork.Roles.GetAllAsync();
            var targetRole = roles.FirstOrDefault(r => r.Id == user.RoleId);

            // Authorization Checks
            if (loggedInRole == "Admin")
            {
                if (targetRole != null && targetRole.Name == "SuperAdmin")
                {
                    return RedirectToAction("AccessDenied", "Account");
                }

                // Verify the form is not trying to set the role to SuperAdmin
                var requestedRoleObj = roles.FirstOrDefault(r => r.Id == model.RoleId);
                if (requestedRoleObj != null && requestedRoleObj.Name == "SuperAdmin")
                {
                    ModelState.AddModelError("RoleId", "Administrators are not permitted to promote accounts to Super Admin.");
                }
            }
            else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                var chefHospitalId = chef?.HospitalId;

                if (targetRole == null || targetRole.Name != "Doctor" || user.HospitalId != chefHospitalId)
                {
                    return RedirectToAction("AccessDenied", "Account");
                }

                // Force properties to prevent tampering
                var doctorRole = roles.FirstOrDefault(r => r.Name == "Doctor");
                model.RoleId = doctorRole?.Id ?? model.RoleId;
                model.HospitalId = chefHospitalId;
            }

            if (ModelState.IsValid)
            {
                // Uniqueness check for username modification
                if (user.Username != model.Username)
                {
                    var existingUser = await _unitOfWork.Users.GetByUsernameAsync(model.Username);
                    if (existingUser != null)
                    {
                        ModelState.AddModelError("Username", "Username is already taken.");
                        
                        var rolesList = await _unitOfWork.Roles.GetAllAsync();
                        var hospitalsList = await _unitOfWork.Hospitals.GetAllAsync();
                        
                        if (loggedInRole == "Admin")
                        {
                            rolesList = rolesList.Where(r => r.Name != "SuperAdmin");
                        }
                        else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId2))
                        {
                            var chef = await _unitOfWork.Users.GetByIdAsync(chefId2);
                            rolesList = rolesList.Where(r => r.Name == "Doctor");
                            hospitalsList = hospitalsList.Where(h => h.Id == chef?.HospitalId);
                        }

                        model.RolesList = rolesList.Select(r => new SelectListItem
                        {
                            Value = r.Id.ToString(),
                            Text = r.Name
                        }).ToList();
                        
                        model.HospitalsList = hospitalsList.Select(h => new SelectListItem
                        {
                            Value = h.Id.ToString(),
                            Text = h.Name
                        }).ToList();

                        return View(model);
                    }
                }

                // Map form changes
                user.Username = model.Username;
                user.FullName = model.FullName;
                user.Email = model.Email;
                user.Phone = model.Phone;
                user.Specialization = model.Specialization;
                user.RoleId = model.RoleId;
                user.HospitalId = model.HospitalId;
                user.IsActive = model.IsActive;

                // Hash password if updating
                if (!string.IsNullOrEmpty(model.Password))
                {
                    user.PasswordHash = _authService.HashPassword(model.Password);
                }

                // Upload new image and dispose of old image
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

                return RedirectToAction(nameof(Index));
            }

            var rolesAll = await _unitOfWork.Roles.GetAllAsync();
            var hospitalsAll = await _unitOfWork.Hospitals.GetAllAsync();
            
            if (loggedInRole == "Admin")
            {
                rolesAll = rolesAll.Where(r => r.Name != "SuperAdmin");
            }
            else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId3))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId3);
                rolesAll = rolesAll.Where(r => r.Name == "Doctor");
                hospitalsAll = hospitalsAll.Where(h => h.Id == chef?.HospitalId);
            }

            model.RolesList = rolesAll.Select(r => new SelectListItem
            {
                Value = r.Id.ToString(),
                Text = r.Name
            }).ToList();
            
            model.HospitalsList = hospitalsAll.Select(h => new SelectListItem
            {
                Value = h.Id.ToString(),
                Text = h.Name
            }).ToList();

            return View(model);
        }

        // Toggle User Active Status (POST)
        [HttpPost]
        public async Task<IActionResult> ToggleActive(int id)
        {
            var user = await _unitOfWork.Users.GetByIdAsync(id);
            if (user == null)
            {
                return NotFound();
            }

            var loggedInRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
            var loggedInUserIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

            var targetRole = await _unitOfWork.Roles.GetByIdAsync(user.RoleId);

            // Authorization Checks
            if (loggedInRole == "Admin")
            {
                if (targetRole != null && targetRole.Name == "SuperAdmin")
                {
                    return RedirectToAction("AccessDenied", "Account");
                }
            }
            else if (loggedInRole == "HospitalChef" && int.TryParse(loggedInUserIdStr, out var chefId))
            {
                var chef = await _unitOfWork.Users.GetByIdAsync(chefId);
                var chefHospitalId = chef?.HospitalId;

                if (targetRole == null || targetRole.Name != "Doctor" || user.HospitalId != chefHospitalId)
                {
                    return RedirectToAction("AccessDenied", "Account");
                }
            }

            user.IsActive = !user.IsActive;
            _unitOfWork.Users.Update(user);
            await _unitOfWork.CompleteAsync();
            
            return RedirectToAction(nameof(Index));
        }
    }
}
