using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class ReportRepository : GenericRepository<Report>, IReportRepository
    {
        public ReportRepository(ClinicDbContext context) : base(context)
        {
        }

        public async Task<IEnumerable<Report>> GetReportsWithDetailsAsync()
        {
            return await _context.Reports
                .Include(r => r.Case)
                    .ThenInclude(c => c.Patient)
                .ToListAsync();
        }

        public async Task<Report?> GetReportWithDetailsAsync(int id)
        {
            return await _context.Reports
                .Include(r => r.Case)
                    .ThenInclude(c => c.Patient)
                .Include(r => r.Case)
                    .ThenInclude(c => c.Doctor)
                .Include(r => r.Case)
                    .ThenInclude(c => c.Diagnoses)
                .Include(r => r.Case)
                    .ThenInclude(c => c.MedicalImages)
                .Include(r => r.Case)
                    .ThenInclude(c => c.AIAnalyses)
                        .ThenInclude(a => a.Findings)
                .FirstOrDefaultAsync(r => r.Id == id);
        }

        public async Task<IEnumerable<Report>> GetReportsByDoctorIdAsync(int doctorId)
        {
            return await _context.Reports
                .Include(r => r.Case)
                    .ThenInclude(c => c.Patient)
                .Where(r => r.Case != null && r.Case.DoctorId == doctorId)
                .ToListAsync();
        }

        public async Task<IEnumerable<Report>> GetReportsByHospitalIdAsync(int hospitalId)
        {
            return await _context.Reports
                .Include(r => r.Case)
                    .ThenInclude(c => c.Patient)
                .Include(r => r.Case)
                    .ThenInclude(c => c.Doctor)
                .Where(r => r.Case != null && r.Case.Doctor != null && r.Case.Doctor.HospitalId == hospitalId)
                .ToListAsync();
        }
    }
}
