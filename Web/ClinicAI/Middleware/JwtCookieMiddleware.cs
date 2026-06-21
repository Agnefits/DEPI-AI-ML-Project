using Microsoft.AspNetCore.Http;
using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Threading.Tasks;

namespace ClinicAI.Middleware
{
    public class JwtCookieMiddleware
    {
        private readonly RequestDelegate _next;

        public JwtCookieMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            string? token = null;

            // 1. Check Authorization header
            if (context.Request.Headers.TryGetValue("Authorization", out var authHeader))
            {
                var val = authHeader.ToString();
                if (val.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                {
                    token = val.Substring(7).Trim();
                }
            }

            // 2. If no header, check Cookie
            if (string.IsNullOrEmpty(token) && context.Request.Cookies.TryGetValue("jwt", out var cookieToken))
            {
                token = cookieToken;
                // Add Authorization header so the standard UseAuthentication middleware parses it
                context.Request.Headers["Authorization"] = $"Bearer {token}";
            }

            // 3. Extract Role if token exists, storing in HttpContext.Items for views
            if (!string.IsNullOrEmpty(token))
            {
                try
                {
                    var handler = new JwtSecurityTokenHandler();
                    if (handler.CanReadToken(token))
                    {
                        var jwtToken = handler.ReadJwtToken(token);
                        
                        // Extract role and username claims
                        var roleClaim = jwtToken.Payload.ContainsKey(ClaimTypes.Role) 
                            ? jwtToken.Payload[ClaimTypes.Role]?.ToString() 
                            : null;
                            
                        // Fallback if role is mapped to a different claim name in JWT payload
                        if (string.IsNullOrEmpty(roleClaim) && jwtToken.Payload.ContainsKey("role"))
                        {
                            roleClaim = jwtToken.Payload["role"]?.ToString();
                        }

                        var usernameClaim = jwtToken.Payload.ContainsKey(ClaimTypes.Name) 
                            ? jwtToken.Payload[ClaimTypes.Name]?.ToString() 
                            : null;
                            
                        if (string.IsNullOrEmpty(usernameClaim) && jwtToken.Payload.ContainsKey("unique_name"))
                        {
                            usernameClaim = jwtToken.Payload["unique_name"]?.ToString();
                        }

                        if (!string.IsNullOrEmpty(roleClaim))
                        {
                            context.Items["UserRole"] = roleClaim;
                        }

                        if (!string.IsNullOrEmpty(usernameClaim))
                        {
                            context.Items["Username"] = usernameClaim;
                        }

                        // Extract custom ImageUrl claim for nav avatar display
                        if (jwtToken.Payload.ContainsKey("ImageUrl"))
                        {
                            var imageUrl = jwtToken.Payload["ImageUrl"]?.ToString();
                            if (!string.IsNullOrEmpty(imageUrl))
                            {
                                context.Items["UserImageUrl"] = imageUrl;
                            }
                        }
                    }
                }
                catch
                {
                    // Ignore parsing errors, standard authentication handler will manage security validation
                }
            }

            await _next(context);
        }
    }
}
