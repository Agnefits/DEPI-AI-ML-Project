using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class HospitalRepository : GenericRepository<Hospital>, IHospitalRepository
    {
        public HospitalRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
