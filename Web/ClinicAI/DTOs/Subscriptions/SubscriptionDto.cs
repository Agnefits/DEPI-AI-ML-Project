using System;

namespace ClinicAI.DTOs.Subscriptions
{
    public class SubscriptionDto
    {
        public int Id { get; set; }
        public int HospitalId { get; set; }
        public string HospitalName { get; set; } = string.Empty;
        public string PlanName { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public string Status { get; set; } = string.Empty;
    }
}
