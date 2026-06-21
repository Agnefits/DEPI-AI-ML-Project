using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class SubscriptionRepository : GenericRepository<Subscription>, ISubscriptionRepository
    {
        public SubscriptionRepository(ClinicDbContext context) : base(context)
        {
        }

        public async Task<IEnumerable<Subscription>> GetSubscriptionsWithHospitalAsync()
        {
            return await _context.Subscriptions
                .Include(s => s.Hospital)
                .ToListAsync();
        }

        public async Task<IEnumerable<Subscription>> GetSubscriptionsByHospitalIdAsync(int hospitalId)
        {
            return await _context.Subscriptions
                .Include(s => s.Hospital)
                .Where(s => s.HospitalId == hospitalId)
                .ToListAsync();
        }
    }
}
