namespace ClinicAI.Models
{
    public class AIFinding
    {
        public int Id { get; set; }
        public int AnalysisId { get; set; }
        public string Finding { get; set; } = string.Empty;
        public double Confidence { get; set; }

        // Navigation property
        public AIAnalysis? Analysis { get; set; }
    }
}
