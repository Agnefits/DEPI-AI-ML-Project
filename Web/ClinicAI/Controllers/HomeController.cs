using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using ClinicAI.ViewModels;
using ClinicAI.UnitOfWork;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace ClinicAI.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly IUnitOfWork _unitOfWork;

        public HomeController(ILogger<HomeController> logger, IUnitOfWork unitOfWork)
        {
            _logger = logger;
            _unitOfWork = unitOfWork ?? throw new System.ArgumentNullException(nameof(unitOfWork));
        }

        public async Task<IActionResult> Index()
        {
            var settings = await _unitOfWork.SystemSettings.FindAsync(s => s.Group == "Mobile" && s.Key == "ApkDownloadUrl");
            var apkUrl = settings.FirstOrDefault()?.Value ?? "";
            ViewBag.ApkDownloadUrl = apkUrl;
            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
