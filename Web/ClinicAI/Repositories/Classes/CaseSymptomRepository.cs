using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class CaseSymptomRepository : GenericRepository<CaseSymptom>, ICaseSymptomRepository
    {
        public CaseSymptomRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
