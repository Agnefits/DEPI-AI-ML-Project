namespace ClinicAI.DTOs.ClinicalNotes
{
    public class ClinicalNoteUpdateDto
    {
        public string Subjective { get; set; } = string.Empty;
        public string Objective { get; set; } = string.Empty;
        public string Assessment { get; set; } = string.Empty;
        public string Plan { get; set; } = string.Empty;
        public string? AdditionalInformation { get; set; }
    }
}
