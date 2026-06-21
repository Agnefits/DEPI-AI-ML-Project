using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class SystemSettingRepository : GenericRepository<SystemSetting>, ISystemSettingRepository
    {
        public SystemSettingRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
