namespace ClinicAI.ViewModels.SystemSettings
{
    public class SystemSettingsVM
    {
        // Storage Settings
        public int MaxUploadSizeMb { get; set; }
        public string AllowedExtensions { get; set; } = string.Empty;
        public string StoragePath { get; set; } = string.Empty;

        // AI Configuration Settings
        public string ClassifyApiUrl { get; set; } = string.Empty;
        public string ClassifyApiKey { get; set; } = string.Empty;
        public string ClassifyModelName { get; set; } = string.Empty;

        public string AnalyzeApiUrl { get; set; } = string.Empty;
        public string AnalyzeApiKey { get; set; } = string.Empty;
        public string AnalyzeModelName { get; set; } = string.Empty;

        public double ConfidenceThreshold { get; set; }

        // SMTP Email Settings
        public string SmtpHost { get; set; } = string.Empty;
        public int SmtpPort { get; set; }
        public string SenderEmail { get; set; } = string.Empty;
        public string SenderPassword { get; set; } = string.Empty;
        public bool EnableSsl { get; set; }

        // Mobile Application Settings
        public string ApkDownloadUrl { get; set; } = string.Empty;
    }
}
