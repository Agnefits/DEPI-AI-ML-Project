using System;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;

namespace ClinicAI.Services.Classes
{
    public class EmailService : IEmailService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IUnitOfWork unitOfWork, ILogger<EmailService> logger)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task SendEmailAsync(string toEmail, string subject, string body)
        {
            try
            {
                var settings = await _unitOfWork.SystemSettings.FindAsync(s => s.Group == "Email");
                var settingsList = settings.ToList();

                var host = settingsList.FirstOrDefault(s => s.Key == "SmtpHost")?.Value;
                var portStr = settingsList.FirstOrDefault(s => s.Key == "SmtpPort")?.Value;
                var senderEmail = settingsList.FirstOrDefault(s => s.Key == "SenderEmail")?.Value;
                var senderPassword = settingsList.FirstOrDefault(s => s.Key == "SenderPassword")?.Value;
                var enableSslStr = settingsList.FirstOrDefault(s => s.Key == "EnableSsl")?.Value;
                var senderFromName = "ClinicAI System";

                // Log email attempt in development/logger
                _logger.LogInformation("==========================================");
                _logger.LogInformation($"[EMAIL SERVICE] Sending to: {toEmail}");
                _logger.LogInformation($"[EMAIL SERVICE] Subject: {subject}");
                _logger.LogInformation("==========================================");

                if (string.IsNullOrEmpty(host) || string.IsNullOrEmpty(senderEmail))
                {
                    _logger.LogWarning("SMTP Server host or sender email not configured. Email logged instead of SMTP.");
                    return;
                }

                int port = 587;
                if (!string.IsNullOrEmpty(portStr))
                {
                    int.TryParse(portStr, out port);
                }

                bool enableSsl = true;
                if (!string.IsNullOrEmpty(enableSslStr))
                {
                    bool.TryParse(enableSslStr, out enableSsl);
                }

                using (var client = new SmtpClient(host))
                {
                    client.Port = port;
                    client.Credentials = new NetworkCredential(senderEmail, senderPassword);
                    client.EnableSsl = enableSsl;

                    var mailMessage = new MailMessage
                    {
                        From = new MailAddress(senderEmail, senderFromName),
                        Subject = subject,
                        Body = body,
                        IsBodyHtml = true
                    };
                    mailMessage.To.Add(toEmail);

                    await client.SendMailAsync(mailMessage);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error sending email to {toEmail}");
            }
        }
    }
}
