using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class PatientRepository : GenericRepository<Patient>, IPatientRepository
    {
        public PatientRepository(ClinicDbContext context) : base(context)
        {
        }

        public async Task<IEnumerable<Patient>> GetPatientsWithDoctorAsync()
        {
            return await _context.Patients
                .Include(p => p.Doctor)
                .ToListAsync();
        }

        public async Task<IEnumerable<Patient>> GetPatientsByDoctorIdAsync(int doctorId)
        {
            return await _context.Patients
                .Include(p => p.Doctor)
                .Where(p => p.DoctorId == doctorId)
                .ToListAsync();
        }

        public async Task<IEnumerable<Patient>> GetPatientsByHospitalIdAsync(int hospitalId)
        {
            return await _context.Patients
                .Include(p => p.Doctor)
                .Where(p => p.Doctor != null && p.Doctor.HospitalId == hospitalId)
                .ToListAsync();
        }
    }
}
