using Microsoft.EntityFrameworkCore;
using ClinicAI.Models;

namespace ClinicAI.Data
{
    public class ClinicDbContext : DbContext
    {
        public ClinicDbContext(DbContextOptions<ClinicDbContext> options)
            : base(options)
        {
        }

        public DbSet<Role> Roles { get; set; }
        public DbSet<User> Users { get; set; }
        public DbSet<Patient> Patients { get; set; }
        public DbSet<Case> Cases { get; set; }
        public DbSet<Symptom> Symptoms { get; set; }
        public DbSet<CaseSymptom> CaseSymptoms { get; set; }
        public DbSet<MedicalImage> MedicalImages { get; set; }
        public DbSet<AIAnalysis> AIAnalyses { get; set; }
        public DbSet<AIFinding> AIFindings { get; set; }
        public DbSet<ClinicalNote> ClinicalNotes { get; set; }
        public DbSet<Diagnosis> Diagnoses { get; set; }
        public DbSet<Report> Reports { get; set; }
        public DbSet<Notification> Notifications { get; set; }
        public DbSet<AuditLog> AuditLogs { get; set; }
        public DbSet<DatasetItem> DatasetItems { get; set; }
        public DbSet<SystemSetting> SystemSettings { get; set; }
        public DbSet<Hospital> Hospitals { get; set; }
        public DbSet<Subscription> Subscriptions { get; set; }
        public DbSet<SmartModel> SmartModels { get; set; }


        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // 1. Roles configuration
            modelBuilder.Entity<Role>(entity =>
            {
                entity.HasKey(r => r.Id);
            });

            // 2. Users configuration
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasKey(u => u.Id);

                entity.HasOne(u => u.Role)
                      .WithMany(r => r.Users)
                      .HasForeignKey(u => u.RoleId)
                      .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(u => u.Hospital)
                      .WithMany()
                      .HasForeignKey(u => u.HospitalId)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // 3. Patients configuration
            modelBuilder.Entity<Patient>(entity =>
            {
                entity.HasKey(p => p.Id);
                entity.Property(p => p.IsArchived).HasDefaultValue(false);

                entity.HasOne(p => p.Doctor)
                      .WithMany()
                      .HasForeignKey(p => p.DoctorId)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // 4. Cases configuration
            modelBuilder.Entity<Case>(entity =>
            {
                entity.HasKey(c => c.Id);

                entity.HasOne(c => c.Patient)
                      .WithMany(p => p.Cases)
                      .HasForeignKey(c => c.PatientId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(c => c.Doctor)
                      .WithMany()
                      .HasForeignKey(c => c.DoctorId)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // 5. Symptoms configuration
            modelBuilder.Entity<Symptom>(entity =>
            {
                entity.HasKey(s => s.Id);
            });

            // 6. CaseSymptoms Many-to-Many Join configuration
            modelBuilder.Entity<CaseSymptom>(entity =>
            {
                entity.HasKey(cs => new { cs.CaseId, cs.SymptomId });

                entity.HasOne(cs => cs.Case)
                      .WithMany(c => c.CaseSymptoms)
                      .HasForeignKey(cs => cs.CaseId)
                      .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(cs => cs.Symptom)
                      .WithMany(s => s.CaseSymptoms)
                      .HasForeignKey(cs => cs.SymptomId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 7. MedicalImages configuration
            modelBuilder.Entity<MedicalImage>(entity =>
            {
                entity.HasKey(mi => mi.Id);

                entity.HasOne(mi => mi.Case)
                      .WithMany(c => c.MedicalImages)
                      .HasForeignKey(mi => mi.CaseId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 8. AIAnalyses configuration
            modelBuilder.Entity<AIAnalysis>(entity =>
            {
                entity.HasKey(a => a.Id);

                entity.HasOne(a => a.Case)
                      .WithMany(c => c.AIAnalyses)
                      .HasForeignKey(a => a.CaseId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 9. AIFindings configuration
            modelBuilder.Entity<AIFinding>(entity =>
            {
                entity.HasKey(f => f.Id);

                entity.HasOne(f => f.Analysis)
                      .WithMany(a => a.Findings)
                      .HasForeignKey(f => f.AnalysisId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 10. ClinicalNotes configuration
            modelBuilder.Entity<ClinicalNote>(entity =>
            {
                entity.HasKey(cn => cn.Id);

                entity.HasOne(cn => cn.Case)
                      .WithMany(c => c.ClinicalNotes)
                      .HasForeignKey(cn => cn.CaseId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 11. Diagnoses configuration
            modelBuilder.Entity<Diagnosis>(entity =>
            {
                entity.HasKey(d => d.Id);

                entity.HasOne(d => d.Case)
                      .WithMany(c => c.Diagnoses)
                      .HasForeignKey(d => d.CaseId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 12. Reports configuration
            modelBuilder.Entity<Report>(entity =>
            {
                entity.HasKey(r => r.Id);

                entity.HasOne(r => r.Case)
                      .WithMany(c => c.Reports)
                      .HasForeignKey(r => r.CaseId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 13. Notifications configuration
            modelBuilder.Entity<Notification>(entity =>
            {
                entity.HasKey(n => n.Id);

                entity.HasOne(n => n.User)
                      .WithMany()
                      .HasForeignKey(n => n.UserId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 14. AuditLogs configuration
            modelBuilder.Entity<AuditLog>(entity =>
            {
                entity.HasKey(al => al.Id);

                entity.HasOne(al => al.User)
                      .WithMany()
                      .HasForeignKey(al => al.UserId)
                      .OnDelete(DeleteBehavior.Restrict);
            });

            // 15. DatasetItems configuration
            modelBuilder.Entity<DatasetItem>(entity =>
            {
                entity.HasKey(d => d.Id);
                entity.Property(d => d.ImagePath).IsRequired().HasMaxLength(500);
                entity.Property(d => d.Label).IsRequired().HasMaxLength(150);
            });

            // 16. SystemSettings configuration
            modelBuilder.Entity<SystemSetting>(entity =>
            {
                entity.HasKey(s => s.Id);
                entity.Property(s => s.Key).IsRequired().HasMaxLength(150);
                entity.Property(s => s.Value).IsRequired();
                entity.Property(s => s.Group).IsRequired().HasMaxLength(100);
                
                entity.HasIndex(s => new { s.Group, s.Key }).IsUnique();
            });

            // 17. Hospitals configuration
            modelBuilder.Entity<Hospital>(entity =>
            {
                entity.HasKey(h => h.Id);
                entity.Property(h => h.Name).IsRequired().HasMaxLength(200);
                entity.Property(h => h.Address).HasMaxLength(300);
                entity.Property(h => h.Phone).HasMaxLength(50);
                entity.Property(h => h.Email).HasMaxLength(150);
            });

            // 18. Subscriptions configuration
            modelBuilder.Entity<Subscription>(entity =>
            {
                entity.HasKey(s => s.Id);
                entity.Property(s => s.PlanName).IsRequired().HasMaxLength(100);
                entity.Property(s => s.Price).HasColumnType("decimal(18,2)");
                entity.Property(s => s.Status).HasMaxLength(50);

                entity.HasOne(s => s.Hospital)
                      .WithMany(h => h.Subscriptions)
                      .HasForeignKey(s => s.HospitalId)
                      .OnDelete(DeleteBehavior.Cascade);
            });

            // 19. SmartModels configuration
            modelBuilder.Entity<SmartModel>(entity =>
            {
                entity.HasKey(sm => sm.Id);
                entity.Property(sm => sm.Name).IsRequired().HasMaxLength(150);
                entity.Property(sm => sm.Version).IsRequired().HasMaxLength(50);
                entity.Property(sm => sm.Description).HasMaxLength(500);
            });
        }
    }
}
