using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class AuditLogRepository : GenericRepository<AuditLog>, IAuditLogRepository
    {
        public AuditLogRepository(ClinicDbContext context) : base(context)
        {
        }

        public async Task<IEnumerable<AuditLog>> GetAuditLogsWithUserAsync()
        {
            return await _context.AuditLogs
                .Include(a => a.User)
                .ToListAsync();
        }
    }
}
