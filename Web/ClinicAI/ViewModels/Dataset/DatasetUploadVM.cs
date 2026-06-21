using System.Collections.Generic;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Rendering;
using ClinicAI.Models;

namespace ClinicAI.ViewModels.Dataset
{
    public class DatasetUploadVM
    {
        public string Label { get; set; } = string.Empty;
        public IFormFile? ImageFile { get; set; }

        public List<SelectListItem> LabelsList { get; set; } = new();
        public List<DatasetItem> UploadedItems { get; set; } = new();
    }
}
