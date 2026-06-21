using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class SmartModelRepository : GenericRepository<SmartModel>, ISmartModelRepository
    {
        public SmartModelRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
