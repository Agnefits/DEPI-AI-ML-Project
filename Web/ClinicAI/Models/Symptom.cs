using System.Collections.Generic;

namespace ClinicAI.Models
{
    public class Symptom
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;

        // Navigation property for Many-to-Many join
        public ICollection<CaseSymptom>? CaseSymptoms { get; set; }
    }
}
