namespace ClinicAI.Models
{
    public class Diagnosis
    {
        public int Id { get; set; }
        public int CaseId { get; set; }
        public string DiagnosisName { get; set; } = string.Empty;
        public string ICD10Code { get; set; } = string.Empty; // Professional ICD-10 medical code
        public double Confidence { get; set; }
        public bool IsFinal { get; set; }

        // Navigation property
        public Case? Case { get; set; }
    }
}
