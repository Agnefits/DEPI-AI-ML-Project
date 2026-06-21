using System;

namespace ClinicAI.Models
{
    public class DatasetItem
    {
        public int Id { get; set; }
        public string ImagePath { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty; // e.g. Pneumonia, Normal, COVID-19
        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
    }
}
