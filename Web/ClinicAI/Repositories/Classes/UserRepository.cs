using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class UserRepository : GenericRepository<User>, IUserRepository
    {
        public UserRepository(ClinicDbContext context) : base(context)
        {
        }

        public async Task<User?> GetByUsernameAsync(string username)
        {
            return await _context.Users
                .Include(u => u.Role)
                .Include(u => u.Hospital)
                .FirstOrDefaultAsync(u => u.Username == username);
        }

        public async Task<User?> GetByEmailAsync(string email)
        {
            return await _context.Users
                .Include(u => u.Role)
                .Include(u => u.Hospital)
                .FirstOrDefaultAsync(u => u.Email == email);
        }

        public async Task<IEnumerable<User>> GetUsersWithRolesAsync()
        {
            return await _context.Users
                .Include(u => u.Role)
                .Include(u => u.Hospital)
                .ToListAsync();
        }

        public async Task<IEnumerable<User>> GetUsersByRoleAsync(string roleName)
        {
            return await _context.Users
                .Include(u => u.Role)
                .Include(u => u.Hospital)
                .Where(u => u.Role != null && u.Role.Name == roleName)
                .ToListAsync();
        }

        public async Task<IEnumerable<User>> GetDoctorsByHospitalIdAsync(int hospitalId)
        {
            return await _context.Users
                .Include(u => u.Role)
                .Include(u => u.Hospital)
                .Where(u => u.Role != null && u.Role.Name == "Doctor" && u.HospitalId == hospitalId)
                .ToListAsync();
        }
    }
}
