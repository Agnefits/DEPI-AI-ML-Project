using System;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;

namespace ClinicAI.Services.Classes
{
    public class EmailService : IEmailService
    {
        private readonly IUnitOfWork _unitOfWork;

        public EmailService(IUnitOfWork unitOfWork)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
        }

        public async Task SendEmailAsync(string toEmail, string subject, string body)
        {
            var settings = await _unitOfWork.SystemSettings.FindAsync(s => s.Group == "Email");
            var settingsList = settings.ToList();

            var host = settingsList.FirstOrDefault(s => s.Key == "SmtpHost")?.Value;
            var portStr = settingsList.FirstOrDefault(s => s.Key == "SmtpPort")?.Value;
            var senderEmail = settingsList.FirstOrDefault(s => s.Key == "SenderEmail")?.Value;
            var senderPassword = settingsList.FirstOrDefault(s => s.Key == "SenderPassword")?.Value;
            var enableSslStr = settingsList.FirstOrDefault(s => s.Key == "EnableSsl")?.Value;

            if (string.IsNullOrEmpty(host) || string.IsNullOrEmpty(senderEmail))
            {
                // Soft fail if configuration is missing in DB
                return;
            }

            int port = int.TryParse(portStr, out var p) ? p : 587;
            bool enableSsl = bool.TryParse(enableSslStr, out var s) ? s : true;

            using var client = new SmtpClient(host, port)
            {
                Credentials = new NetworkCredential(senderEmail, senderPassword),
                EnableSsl = enableSsl
            };

            var mailMessage = new MailMessage
            {
                From = new MailAddress(senderEmail),
                Subject = subject,
                Body = body,
                IsBodyHtml = true
            };
            mailMessage.To.Add(toEmail);

            await client.SendMailAsync(mailMessage);
        }
    }
}
