using ClinicAI.Data;
using ClinicAI.Models;
using ClinicAI.Repositories.Interfaces;

namespace ClinicAI.Repositories.Classes
{
    public class DatasetItemRepository : GenericRepository<DatasetItem>, IDatasetItemRepository
    {
        public DatasetItemRepository(ClinicDbContext context) : base(context)
        {
        }
    }
}
