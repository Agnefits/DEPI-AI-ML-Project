using ClinicAI.Models;
using System.Collections.Generic;

namespace ClinicAI.Repositories.Interfaces
{
    public interface IAIAnalysisRepository : IGenericRepository<AIAnalysis>
    {
        Task<IEnumerable<AIAnalysis>> GetAnalysesWithDetailsAsync();
    }
}
