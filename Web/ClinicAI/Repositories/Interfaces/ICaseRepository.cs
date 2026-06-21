using ClinicAI.Models;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ClinicAI.Repositories.Interfaces
{
    public interface ICaseRepository : IGenericRepository<Case>
    {
        Task<IEnumerable<Case>> GetCasesWithDetailsAsync();
        Task<IEnumerable<Case>> GetCasesByDoctorIdAsync(int doctorId);
        Task<IEnumerable<Case>> GetCasesByHospitalIdAsync(int hospitalId);
    }
}
