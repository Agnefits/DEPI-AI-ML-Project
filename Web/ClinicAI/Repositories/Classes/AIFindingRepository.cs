using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class AIFindingRepository : GenericRepository<AIFinding>, IAIFindingRepository
    {
        public AIFindingRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
