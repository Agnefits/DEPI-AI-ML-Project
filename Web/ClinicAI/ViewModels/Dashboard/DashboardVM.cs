using System.Collections.Generic;

namespace ClinicAI.ViewModels.Dashboard
{
    public class DashboardVM
    {
        // Statistics Counter
        public int UsersCount { get; set; }
        public int PatientsCount { get; set; }
        public int CasesCount { get; set; }
        public int DiagnosesCount { get; set; }
        public int AIUsageCount { get; set; }

        // Chart Data - Daily Cases (Last 7 Days)
        public List<string> DailyLabels { get; set; } = new();
        public List<int> DailyData { get; set; } = new();

        // Chart Data - Monthly Cases
        public List<string> MonthlyLabels { get; set; } = new();
        public List<int> MonthlyData { get; set; } = new();

        // Chart Data - Most Common Diseases
        public List<string> DiseaseLabels { get; set; } = new();
        public List<int> DiseaseData { get; set; } = new();
    }
}
