using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class DiagnosisRepository : GenericRepository<Diagnosis>, IDiagnosisRepository
    {
        public DiagnosisRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
