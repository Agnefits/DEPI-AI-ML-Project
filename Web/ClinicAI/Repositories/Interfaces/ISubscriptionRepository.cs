using ClinicAI.Models;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ClinicAI.Repositories.Interfaces
{
    public interface ISubscriptionRepository : IGenericRepository<Subscription>
    {
        Task<IEnumerable<Subscription>> GetSubscriptionsWithHospitalAsync();
        Task<IEnumerable<Subscription>> GetSubscriptionsByHospitalIdAsync(int hospitalId);
    }
}
