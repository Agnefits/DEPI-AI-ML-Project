using System.Threading.Tasks;
using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Classes;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.UnitOfWork
{
    public class UnitOfWork : IUnitOfWork
    {
        private readonly ClinicDbContext _context;

        public IUserRepository Users { get; private set; }
        public IRoleRepository Roles { get; private set; }
        public IPatientRepository Patients { get; private set; }
        public ICaseRepository Cases { get; private set; }
        public ISymptomRepository Symptoms { get; private set; }
        public ICaseSymptomRepository CaseSymptoms { get; private set; }
        public IMedicalImageRepository MedicalImages { get; private set; }
        public IAIAnalysisRepository AIAnalyses { get; private set; }
        public IAIFindingRepository AIFindings { get; private set; }
        public IClinicalNoteRepository ClinicalNotes { get; private set; }
        public IDiagnosisRepository Diagnoses { get; private set; }
        public IReportRepository Reports { get; private set; }
        public INotificationRepository Notifications { get; private set; }
        public IAuditLogRepository AuditLogs { get; private set; }
        public IDatasetItemRepository DatasetItems { get; private set; }
        public ISystemSettingRepository SystemSettings { get; private set; }
        public IHospitalRepository Hospitals { get; private set; }
        public ISubscriptionRepository Subscriptions { get; private set; }
        public ISmartModelRepository SmartModels { get; private set; }
 
        public UnitOfWork(ClinicDbContext context)
        {
            _context = context;
            
            Users = new UserRepository(_context);
            Roles = new RoleRepository(_context);
            Patients = new PatientRepository(_context);
            Cases = new CaseRepository(_context);
            Symptoms = new SymptomRepository(_context);
            CaseSymptoms = new CaseSymptomRepository(_context);
            MedicalImages = new MedicalImageRepository(_context);
            AIAnalyses = new AIAnalysisRepository(_context);
            AIFindings = new AIFindingRepository(_context);
            ClinicalNotes = new ClinicalNoteRepository(_context);
            Diagnoses = new DiagnosisRepository(_context);
            Reports = new ReportRepository(_context);
            Notifications = new NotificationRepository(_context);
            AuditLogs = new AuditLogRepository(_context);
            DatasetItems = new DatasetItemRepository(_context);
            SystemSettings = new SystemSettingRepository(_context);
            Hospitals = new HospitalRepository(_context);
            Subscriptions = new SubscriptionRepository(_context);
            SmartModels = new SmartModelRepository(_context);
        }

        public async Task<int> CompleteAsync()
        {
            return await _context.SaveChangesAsync();
        }

        public void Dispose()
        {
            _context.Dispose();
        }
    }
}
