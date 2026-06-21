using System.Threading.Tasks;
using ClinicAI.Models;
using System.Collections.Generic;

namespace ClinicAI.Repositories.Interfaces
{
    public interface IUserRepository : IGenericRepository<User>
    {
        Task<User?> GetByUsernameAsync(string username);
        Task<User?> GetByEmailAsync(string email);
        Task<IEnumerable<User>> GetUsersWithRolesAsync();
        Task<IEnumerable<User>> GetUsersByRoleAsync(string roleName);
        Task<IEnumerable<User>> GetDoctorsByHospitalIdAsync(int hospitalId);
    }
}
