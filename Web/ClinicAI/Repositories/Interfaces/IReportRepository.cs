using ClinicAI.Models;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ClinicAI.Repositories.Interfaces
{
    public interface IReportRepository : IGenericRepository<Report>
    {
        Task<IEnumerable<Report>> GetReportsWithDetailsAsync();
        Task<Report?> GetReportWithDetailsAsync(int id);
        Task<IEnumerable<Report>> GetReportsByDoctorIdAsync(int doctorId);
        Task<IEnumerable<Report>> GetReportsByHospitalIdAsync(int hospitalId);
    }
}
