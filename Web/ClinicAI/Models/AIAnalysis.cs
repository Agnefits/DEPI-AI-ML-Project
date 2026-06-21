using System;
using System.Collections.Generic;

namespace ClinicAI.Models
{
    public class AIAnalysis
    {
        public int Id { get; set; }
        public int CaseId { get; set; }
        public string ModelVersion { get; set; } = string.Empty;
        public double Confidence { get; set; }
        public double ProcessingTime { get; set; } // in seconds or milliseconds
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public Case? Case { get; set; }
        public ICollection<AIFinding>? Findings { get; set; }
    }
}
