namespace ClinicAI.DTOs.Cases
{
    public class CaseUpdateDto
    {
        public string Status { get; set; } = "Pending"; // Pending, In Progress, Completed
        public string Priority { get; set; } = "Medium";
        public string? AdditionalInformation { get; set; }
    }
}
