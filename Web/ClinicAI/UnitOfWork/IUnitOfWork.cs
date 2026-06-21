using System;
using System.Threading.Tasks;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.UnitOfWork
{
    public interface IUnitOfWork : IDisposable
    {
        IUserRepository Users { get; }
        IRoleRepository Roles { get; }
        IPatientRepository Patients { get; }
        ICaseRepository Cases { get; }
        ISymptomRepository Symptoms { get; }
        ICaseSymptomRepository CaseSymptoms { get; }
        IMedicalImageRepository MedicalImages { get; }
        IAIAnalysisRepository AIAnalyses { get; }
        IAIFindingRepository AIFindings { get; }
        IClinicalNoteRepository ClinicalNotes { get; }
        IDiagnosisRepository Diagnoses { get; }
        IReportRepository Reports { get; }
        INotificationRepository Notifications { get; }
        IAuditLogRepository AuditLogs { get; }
        IDatasetItemRepository DatasetItems { get; }
        ISystemSettingRepository SystemSettings { get; }
        IHospitalRepository Hospitals { get; }
        ISubscriptionRepository Subscriptions { get; }
        ISmartModelRepository SmartModels { get; }
        
        Task<int> CompleteAsync();
    }
}
