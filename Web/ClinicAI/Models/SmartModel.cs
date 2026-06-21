using System;

namespace ClinicAI.Models
{
    public class SmartModel
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty; // e.g. Chest X-Ray Model
        public string Version { get; set; } = string.Empty; // e.g. v1.0, v2.1
        public string Description { get; set; } = string.Empty;
        public double Accuracy { get; set; } // e.g. 0.95 (95% accuracy)
        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
