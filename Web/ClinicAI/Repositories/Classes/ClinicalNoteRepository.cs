using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class ClinicalNoteRepository : GenericRepository<ClinicalNote>, IClinicalNoteRepository
    {
        public ClinicalNoteRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
