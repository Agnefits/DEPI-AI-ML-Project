namespace ClinicAI.Models
{
    public class CaseSymptom
    {
        public int CaseId { get; set; }
        public Case? Case { get; set; }

        public int SymptomId { get; set; }
        public Symptom? Symptom { get; set; }
    }
}
