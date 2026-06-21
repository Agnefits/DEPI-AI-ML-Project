using System;

namespace ClinicAI.Models
{
    public class Subscription
    {
        public int Id { get; set; }
        public int HospitalId { get; set; }
        public string PlanName { get; set; } = string.Empty; // e.g. Basic, Premium, Enterprise
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal Price { get; set; }
        public string Status { get; set; } = "Active"; // e.g. Active, Expired, Suspended
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public Hospital? Hospital { get; set; }
    }
}
