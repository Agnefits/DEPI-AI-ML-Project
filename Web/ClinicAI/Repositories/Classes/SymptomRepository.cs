using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class SymptomRepository : GenericRepository<Symptom>, ISymptomRepository
    {
        public SymptomRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
