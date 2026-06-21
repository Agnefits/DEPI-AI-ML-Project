using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace ClinicAI.Attributes
{
    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = true)]
    public class AuthorizedRolesAttribute : Attribute, IAsyncAuthorizationFilter
    {
        public string[] Roles { get; }

        public AuthorizedRolesAttribute(params string[] roles)
        {
            Roles = roles;
        }

        public Task OnAuthorizationAsync(AuthorizationFilterContext context)
        {
            var user = context.HttpContext.User;

            // 1. Check if user is authenticated
            if (user == null || user.Identity == null || !user.Identity.IsAuthenticated)
            {
                HandleUnauthorized(context);
                return Task.CompletedTask;
            }

            // 2. Check if user belongs to any of the allowed roles
            // Handle spaces and casing flexibly (e.g. "Super Admin" matches "SuperAdmin")
            bool isAuthorized = false;
            var userRoles = user.FindAll(ClaimTypes.Role).Select(c => c.Value.Replace(" ", "").ToLower()).ToList();

            foreach (var role in Roles)
            {
                var normalizedRole = role.Replace(" ", "").ToLower();
                if (userRoles.Contains(normalizedRole))
                {
                    isAuthorized = true;
                    break;
                }
            }

            if (!isAuthorized)
            {
                HandleForbidden(context);
            }

            return Task.CompletedTask;
        }

        private void HandleUnauthorized(AuthorizationFilterContext context)
        {
            var path = context.HttpContext.Request.Path.Value ?? string.Empty;
            if (path.StartsWith("/api/", StringComparison.OrdinalIgnoreCase))
            {
                context.Result = new JsonResult(new { message = "Unauthorized access. Token is missing or invalid." })
                {
                    StatusCode = StatusCodes.Status401Unauthorized
                };
            }
            else
            {
                // For web UI pages, redirect to login
                context.Result = new RedirectToActionResult("Login", "Account", null);
            }
        }

        private void HandleForbidden(AuthorizationFilterContext context)
        {
            var path = context.HttpContext.Request.Path.Value ?? string.Empty;
            if (path.StartsWith("/api/", StringComparison.OrdinalIgnoreCase))
            {
                context.Result = new JsonResult(new { message = "Forbidden. You do not have permission to access this resource." })
                {
                    StatusCode = StatusCodes.Status403Forbidden
                };
            }
            else
            {
                // For web UI pages, redirect to Access Denied
                context.Result = new RedirectToActionResult("AccessDenied", "Account", null);
            }
        }
    }
}
