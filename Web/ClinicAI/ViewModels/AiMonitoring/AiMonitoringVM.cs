using System;
using System.Collections.Generic;

namespace ClinicAI.ViewModels.AiMonitoring
{
    public class AiMonitoringVM
    {
        public int TotalAnalysesCount { get; set; }
        public double AverageAccuracy { get; set; } // average confidence score
        public double AverageProcessingTime { get; set; } // in seconds
        public int FailedPredictionsCount { get; set; } // analyses with low confidence

        public string ModelName { get; set; } = "ClinicMODELv0";
        public double ConfidenceThreshold { get; set; } = 0.70;

        public List<RecentAnalysisVM> RecentAnalyses { get; set; } = new();
    }
}
