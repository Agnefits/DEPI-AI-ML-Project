using System;
using System.IO;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using ClinicAI.Models;
using ClinicAI.Services.Interfaces;
using ClinicAI.UnitOfWork;
using ClinicAI.DTOs.Images;

namespace ClinicAI.APIControllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ImagesApiController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IFileService _fileService;

        public ImagesApiController(IUnitOfWork unitOfWork, IFileService fileService)
        {
            _unitOfWork = unitOfWork ?? throw new ArgumentNullException(nameof(unitOfWork));
            _fileService = fileService ?? throw new ArgumentNullException(nameof(fileService));
        }

        [HttpPost("upload/{caseId}")]
        public async Task<IActionResult> UploadImage(int caseId, IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest("Please upload a valid scan image.");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!int.TryParse(userIdStr, out var loggedInUserId))
            {
                return Unauthorized();
            }

            var targetCase = await _unitOfWork.Cases.GetByIdAsync(caseId);
            if (targetCase == null)
            {
                return NotFound($"Case with ID {caseId} does not exist.");
            }

            // Doctor ownership checks
            if (userRole == "Doctor" && targetCase.DoctorId != loggedInUserId)
            {
                return Forbid("Access Denied: You cannot upload scans for another doctor's case.");
            }

            try
            {
                // Save original file to disk
                var savedFilePath = await _fileService.SaveFileAsync(file, "medical-images");

                // Simulate Image Compression (e.g. reduce size by 55%)
                long originalSize = file.Length;
                long compressedSize = (long)(originalSize * 0.45);
                double compressionRatioPercent = 55.0;

                // Log medical image in DB
                var medicalImage = new MedicalImage
                {
                    CaseId = caseId,
                    FilePath = savedFilePath,
                    ImageType = file.ContentType.Contains("image") ? "Scan" : "Attachment",
                    UploadedAt = DateTime.UtcNow
                };

                await _unitOfWork.MedicalImages.AddAsync(medicalImage);
                await _unitOfWork.CompleteAsync();

                var response = new ImageUploadResponseDto
                {
                    ImageId = medicalImage.Id,
                    CaseId = caseId,
                    FilePath = savedFilePath,
                    ImageType = medicalImage.ImageType,
                    OriginalSizeBytes = originalSize,
                    CompressedSizeBytes = compressedSize,
                    CompressionRatio = $"{compressionRatioPercent}% size reduction (Simulated Quality Optimization)"
                };

                return Ok(response);
            }
            catch (Exception ex)
            {
                return StatusCode(StatusCodes.Status500InternalServerError, new { error = ex.Message });
            }
        }
    }
}
