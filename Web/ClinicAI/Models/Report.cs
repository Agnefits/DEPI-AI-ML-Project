namespace ClinicAI.Models
{
    public class Report
    {
        public int Id { get; set; }
        public int CaseId { get; set; }
        public string ReportContent { get; set; } = string.Empty;
        public string? ReportPdf { get; set; } // path to the generated PDF report
        public string Status { get; set; } = string.Empty; // e.g. Pending, Generated, Signed
        public string? AdditionalInformation  { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation property
        public Case? Case { get; set; }
    }
}
