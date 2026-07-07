using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;

namespace ClinicAI.Services.Interfaces
{
    public interface IAiService
    {
        Task<string> ClassifyScanAsync(IFormFile file, bool includeGridcam = false);
        Task<string> AnalyzePromptAsync(string? prompt, IFormFile? file);
    }
}
