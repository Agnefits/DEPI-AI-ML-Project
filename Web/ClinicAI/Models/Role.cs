using System.Collections.Generic;

namespace ClinicAI.Models
{
    public class Role
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty; // Doctor, Radiologist, Admin, SuperAdmin

        // Navigation property
        public ICollection<User>? Users { get; set; }
    }
}
