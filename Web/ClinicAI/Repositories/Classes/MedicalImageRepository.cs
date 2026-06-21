using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class MedicalImageRepository : GenericRepository<MedicalImage>, IMedicalImageRepository
    {
        public MedicalImageRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
