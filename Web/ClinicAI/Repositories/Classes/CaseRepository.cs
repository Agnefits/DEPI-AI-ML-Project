using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class CaseRepository : GenericRepository<Case>, ICaseRepository
    {
        public CaseRepository(ClinicDbContext context) : base(context)
        {
        }

        public async Task<IEnumerable<Case>> GetCasesWithDetailsAsync()
        {
            return await _context.Cases
                .Include(c => c.Patient)
                .Include(c => c.Doctor)
                .Include(c => c.Diagnoses)
                .ToListAsync();
        }

        public async Task<IEnumerable<Case>> GetCasesByDoctorIdAsync(int doctorId)
        {
            return await _context.Cases
                .Include(c => c.Patient)
                .Include(c => c.Doctor)
                .Include(c => c.Diagnoses)
                .Where(c => c.DoctorId == doctorId)
                .ToListAsync();
        }

        public async Task<IEnumerable<Case>> GetCasesByHospitalIdAsync(int hospitalId)
        {
            return await _context.Cases
                .Include(c => c.Patient)
                .Include(c => c.Doctor)
                .Include(c => c.Diagnoses)
                .Where(c => c.Doctor != null && c.Doctor.HospitalId == hospitalId)
                .ToListAsync();
        }
    }
}
