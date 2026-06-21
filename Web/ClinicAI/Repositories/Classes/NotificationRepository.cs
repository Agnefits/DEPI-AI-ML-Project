using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class NotificationRepository : GenericRepository<Notification>, INotificationRepository
    {
        public NotificationRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
