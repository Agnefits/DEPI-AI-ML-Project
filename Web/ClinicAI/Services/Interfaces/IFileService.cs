using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;

namespace ClinicAI.Services.Interfaces
{
    public interface IFileService
    {
        Task<string> SaveFileAsync(IFormFile file, string subFolder);
        void DeleteFile(string relativePath);
    }
}
