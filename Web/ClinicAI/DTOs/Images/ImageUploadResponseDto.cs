using System;

namespace ClinicAI.DTOs.Images
{
    public class ImageUploadResponseDto
    {
        public int ImageId { get; set; }
        public int CaseId { get; set; }
        public string FilePath { get; set; } = string.Empty;
        public string ImageType { get; set; } = string.Empty;
        public long OriginalSizeBytes { get; set; }
        public long CompressedSizeBytes { get; set; }
        public string CompressionRatio { get; set; } = string.Empty;
        public DateTime UploadedAt { get; set; }
    }
}
