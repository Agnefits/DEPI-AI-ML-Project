using ClinicAI.Models;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ClinicAI.Repositories.Interfaces
{
    public interface IPatientRepository : IGenericRepository<Patient>
    {
        Task<IEnumerable<Patient>> GetPatientsWithDoctorAsync();
        Task<IEnumerable<Patient>> GetPatientsByDoctorIdAsync(int doctorId);
        Task<IEnumerable<Patient>> GetPatientsByHospitalIdAsync(int hospitalId);
    }
}
