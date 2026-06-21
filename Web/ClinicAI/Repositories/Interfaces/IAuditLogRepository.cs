using ClinicAI.Models;
using System.Collections.Generic;

namespace ClinicAI.Repositories.Interfaces
{
    public interface IAuditLogRepository : IGenericRepository<AuditLog>
    {
        Task<IEnumerable<AuditLog>> GetAuditLogsWithUserAsync();
    }
}
