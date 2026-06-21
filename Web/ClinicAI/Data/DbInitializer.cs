using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ClinicAI.Models;
using ClinicAI.Services.Interfaces;

namespace ClinicAI.Data
{
    public static class DbInitializer
    {
        public static async Task SeedAsync(IServiceProvider serviceProvider)
        {
            using var context = serviceProvider.GetRequiredService<ClinicDbContext>();

            // 1. Seed Roles if none exist
            if (!await context.Roles.AnyAsync())
            {
                var roles = new[]
                {
                    new Role { Name = "SuperAdmin" },
                    new Role { Name = "Admin" },
                    new Role { Name = "Doctor" },
                    new Role { Name = "Radiologist" },
                    new Role { Name = "HospitalChef" }
                };

                await context.Roles.AddRangeAsync(roles);
                await context.SaveChangesAsync();
            }

            // 2. Seed default Administrator User if database has no users
            if (!await context.Users.AnyAsync())
            {
                var authService = serviceProvider.GetRequiredService<IAuthService>();
                
                var superAdminRole = await context.Roles.FirstOrDefaultAsync(r => r.Name == "SuperAdmin");
                int roleId = superAdminRole?.Id ?? 1; // default fallback if query fails

                var adminUser = new User
                {
                    Username = "admin",
                    FullName = "System Administrator",
                    Email = "admin@clinicai.com",
                    PasswordHash = authService.HashPassword("Admin@123"),
                    Phone = "+1234567890",
                    RoleId = roleId,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                };

                await context.Users.AddAsync(adminUser);
                await context.SaveChangesAsync();
            }

            // 3. Seed SystemSettings if none exist
            if (!await context.SystemSettings.AnyAsync())
            {
                var settings = new[]
                {
                    // Storage settings
                    new SystemSetting { Group = "Storage", Key = "MaxUploadSizeMb", Value = "25" },
                    new SystemSetting { Group = "Storage", Key = "AllowedExtensions", Value = ".jpg,.jpeg,.png,.pdf,.dcm" },
                    new SystemSetting { Group = "Storage", Key = "StoragePath", Value = "wwwroot/uploads/" },

                    // AI Configuration Settings
                    new SystemSetting { Group = "AI", Key = "ApiUrl", Value = "https://api.gemini-model.example/v1/chat/completions" },
                    new SystemSetting { Group = "AI", Key = "ApiKey", Value = "gemini-api-key-goes-here" },
                    new SystemSetting { Group = "AI", Key = "ModelName", Value = "clinicMODELv0" },
                    new SystemSetting { Group = "AI", Key = "ConfidenceThreshold", Value = "0.70" },

                    // SMTP Email Settings
                    new SystemSetting { Group = "Email", Key = "SmtpHost", Value = "smtp.gmail.com" },
                    new SystemSetting { Group = "Email", Key = "SmtpPort", Value = "587" },
                    new SystemSetting { Group = "Email", Key = "SenderEmail", Value = "mvc.email.sender@gmail.com.com" },
                    new SystemSetting { Group = "Email", Key = "SenderPassword", Value = "sxyz nfee cwkb dbrb" },
                    new SystemSetting { Group = "Email", Key = "EnableSsl", Value = "true" }
                };

                await context.SystemSettings.AddRangeAsync(settings);
                await context.SaveChangesAsync();
            }
        }
    }
}
