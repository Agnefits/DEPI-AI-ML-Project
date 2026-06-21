namespace ClinicAI.ViewModels.SystemSettings
{
    public class SystemSettingsVM
    {
        // Storage Settings
        public int MaxUploadSizeMb { get; set; }
        public string AllowedExtensions { get; set; } = string.Empty;
        public string StoragePath { get; set; } = string.Empty;

        // AI Configuration Settings
        public string ApiUrl { get; set; } = string.Empty;
        public string ApiKey { get; set; } = string.Empty;
        public string ModelName { get; set; } = string.Empty;
        public double ConfidenceThreshold { get; set; }

        // SMTP Email Settings
        public string SmtpHost { get; set; } = string.Empty;
        public int SmtpPort { get; set; }
        public string SenderEmail { get; set; } = string.Empty;
        public string SenderPassword { get; set; } = string.Empty;
        public bool EnableSsl { get; set; }
    }
}
