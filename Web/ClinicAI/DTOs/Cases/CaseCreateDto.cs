namespace ClinicAI.DTOs.Cases
{
    public class CaseCreateDto
    {
        public int PatientId { get; set; }
        public string Priority { get; set; } = "Medium"; // Low, Medium, High
        public string? AdditionalInformation { get; set; }
    }
}
