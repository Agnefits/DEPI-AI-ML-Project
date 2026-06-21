using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class AIAnalysisRepository : GenericRepository<AIAnalysis>, IAIAnalysisRepository
    {
        public AIAnalysisRepository(ClinicDbContext context) : base(context)
        {
        }

        public async Task<IEnumerable<AIAnalysis>> GetAnalysesWithDetailsAsync()
        {
            return await _context.AIAnalyses
                .Include(a => a.Case)
                    .ThenInclude(c => c.Patient)
                .Include(a => a.Findings)
                .ToListAsync();
        }
    }
}
