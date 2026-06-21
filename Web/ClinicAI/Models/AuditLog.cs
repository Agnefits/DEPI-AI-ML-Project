using System;

namespace ClinicAI.Models
{
    public class AuditLog
    {
        public int Id { get; set; }
        public int? UserId { get; set; } // Nullable if system-triggered
        public string Action { get; set; } = string.Empty; // e.g. Create, Update, Delete
        public string EntityName { get; set; } = string.Empty; // e.g. Patient, Case, User
        public int EntityId { get; set; }
        public string? OldValue { get; set; } // serialized state before change
        public string? NewValue { get; set; } // serialized state after change
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation property
        public User? User { get; set; }
    }
}
