import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:ilovepdf_flutter/utils/platform_file_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ilovepdf_flutter/services/pdf_compressor_service.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';
import 'package:printing/printing.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  PlatformFile? _selectedFile;
  CompressionQuality _selectedQuality = CompressionQuality.balanced;
  bool _isLoading = false;
  bool _isLoadingInfo = false;
  double _progress = 0.0;
  CompressionResult? _compressionResult;
  EstimatedCompression? _estimate;
  int? _pageCount;
  Uint8List? _thumbnail;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      // Preload interstitial ad so it's ready when operation completes
      AdService().preloadForOperation();
      
      setState(() {
        _selectedFile = result.files.first;
        _compressionResult = null;
        _estimate = null;
        _pageCount = null;
        _thumbnail = null;
        _isLoadingInfo = true;
      });
      await _loadPdfInfo();
    }
  }

  Future<void> _loadPdfInfo() async {
    if (_selectedFile == null) return;
    
    try {
      if (kIsWeb) {
        // Web implementation
        final bytes = _selectedFile!.bytes!;
        
        // Ensure we have bytes
        if (bytes.isEmpty) return;

        // Estimate (mock or simple calc for web since full estimation might be heavy)
         // For now, let's just skip complex estimation or do a simple one
         final originalSize = bytes.length;
         final estimate = EstimatedCompression(
            originalSize: originalSize,
            estimatedSize: (originalSize * 0.6).toInt(), // Rough estimate
            estimatedRatio: 40,
            quality: _selectedQuality,
         );
        
        // Get thumbnail
        Uint8List? thumb;
        try {
          await for (final page in Printing.raster(bytes, dpi: 50, pages: [0])) {
            thumb = await page.toPng();
            break;
          }
        } catch (e) {
          debugPrint('Thumbnail generation failed: $e');
        }
        
        setState(() {
          _estimate = estimate;
          _thumbnail = thumb;
          _isLoadingInfo = false;
        });
        
      } else {
        // Mobile implementation
        if (_selectedFile?.path == null) return;
        
        // Get estimate
        final estimate = await PdfCompressor.estimateCompression(
          inputPath: _selectedFile!.path!,
          quality: _selectedQuality,
        );
        
        // Get thumbnail
        final bytes = await File(_selectedFile!.path!).readAsBytes();
        Uint8List? thumb;
        await for (final page in Printing.raster(bytes, dpi: 50, pages: [0])) {
          thumb = await page.toPng();
          break;
        }
        
        setState(() {
          _estimate = estimate;
          _thumbnail = thumb;
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingInfo = false);
      debugPrint('Error loading PDF info: $e');
    }
  }

  Future<void> _updateEstimate() async {
    if (_selectedFile == null) return;
    
    try {
      if (kIsWeb) {
         // Update estimate for web if needed
         final originalSize = _selectedFile!.bytes!.length;
          final estimate = EstimatedCompression(
            originalSize: originalSize,
            estimatedSize: (originalSize * 0.6).toInt(), // Rough estimate
            estimatedRatio: 40,
            quality: _selectedQuality,
         );
         setState(() => _estimate = estimate);
      } else {
        if (_selectedFile?.path == null) return;
        final estimate = await PdfCompressor.estimateCompression(
          inputPath: _selectedFile!.path!,
          quality: _selectedQuality,
        );
        setState(() => _estimate = estimate);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _compressFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
    });

    try {
      CompressionResult result;
      
      if (kIsWeb) {
        // Web implementation
        final bytes = _selectedFile!.bytes!;
        final compressedBytes = await PdfCompressor.compressPdfFromBytes(
          inputBytes: bytes,
          quality: _selectedQuality,
          onProgress: (progress) {
             setState(() => _progress = progress);
          },
        );
        
        // Save file
        final fileName = 'compressed_${_selectedFile!.name}';
        await PlatformFileUtils.saveFile(fileName, compressedBytes);
        
        final compressedSize = compressedBytes.length;
        final originalSize = bytes.length;
        
        result = CompressionResult(
          success: true,
          inputPath: _selectedFile!.name,
          outputPath: fileName, // Display name
          originalSize: originalSize,
          compressedSize: compressedSize,
          compressionRatio: ((originalSize - compressedSize) / originalSize * 100),
          pageCount: 0, // Unknown without checking doc again
          duration: Duration.zero, // Track if needed
          quality: _selectedQuality,
        );
        
      } else {
        // Mobile implementation
        final tempDir = await getTemporaryDirectory();
        final outputPath = '${tempDir.path}/compressed_${_selectedFile!.name}';
        
        result = await PdfCompressor.compressPdf(
          inputPath: _selectedFile!.path!,
          outputPath: outputPath,
          quality: _selectedQuality,
          onProgress: (progress) {
            setState(() => _progress = progress);
          },
        );
      }
      
      setState(() {
        _isLoading = false;
        _compressionResult = result;
      });
      
      // Add to history
      await HistoryUtils.addToHistoryWithSize(
        context: context,
        fileName: 'compressed_${_selectedFile!.name}',
        toolName: 'Compress PDF',
        toolId: 'compress',
        filePath: result.outputPath,
        fileSize: result.compressedSize,
      );
      
      // Show interstitial ad after successful operation
      AdService().showInterstitialAfterOperation();
      
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    if (_compressionResult == null) return;
    await Share.shareXFiles([XFile(_compressionResult!.outputPath)]);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getContentScale(context);
    return BaseScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compress PDF'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => HelpDialog.show(context, 'compress'),
              tooltip: 'Help',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E3A59), Color(0xFF1E2A49)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4A80F0), width: 2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Compress PDF',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reduce file size while maintaining quality',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.compress, color: Colors.white, size: 32 * scale),
                      ),
                    ],
                  ),
                ),

                // PDF Selection Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (_thumbnail != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(_thumbnail!, height: 120, fit: BoxFit.contain),
                            )
                          else
                            Icon(
                              Icons.picture_as_pdf,
                              size: 56,
                              color: Theme.of(context).primaryColor,
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _pickFile,
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: Text(_selectedFile == null ? 'Select PDF' : 'Change PDF'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (_selectedFile != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A80F0).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _selectedFile!.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500, 
                                      fontSize: 13,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : const Color(0xFF2E3A59),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatBytes(_selectedFile!.size),
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFFB0BEC5)
                                          : Colors.grey[600], 
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_isLoadingInfo)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_selectedFile != null && !_isLoadingInfo) ...[
                  const SizedBox(height: 24),

                  // Quality Presets
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Compression Level',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white : const Color(0xFF2E3A59),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Preset Cards Grid
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildGridPreset(CompressionQuality.maximum, 'Max', Icons.compress, Colors.red),
                        _buildGridPreset(CompressionQuality.high, 'High', Icons.arrow_downward, Colors.orange),
                        _buildGridPreset(CompressionQuality.balanced, 'Medium', Icons.balance, Colors.blue),
                        _buildGridPreset(CompressionQuality.low, 'Low', Icons.high_quality, Colors.green),
                        _buildGridPreset(CompressionQuality.minimal, 'Min', Icons.hd, Colors.purple),
                      ],
                    ),
                  ),

                  // Estimated Result
                  if (_estimate != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Estimated Result',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text('Current', style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFB0BEC5)
                                        : Colors.grey[600], 
                                    fontSize: 12,
                                  )),
                                  Text(
                                    _estimate!.originalSizeFormatted,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              Icon(Icons.arrow_forward, color: Colors.blue[400]),
                              Column(
                                children: [
                                  Text('Expected', style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFB0BEC5)
                                        : Colors.grey[600], 
                                    fontSize: 12,
                                  )),
                                  Text(
                                    _estimate!.estimatedSizeFormatted,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '-${_estimate!.estimatedRatio.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Progress
                  if (_isLoading) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A80F0)),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 12),
                          Text('Compressing... ${(_progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Compress Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _compressFile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF4A80F0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Compress PDF',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),

                  // Results
                  if (_compressionResult != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 48 * scale),
                          const SizedBox(height: 12),
                          Text(
                            'Compression Complete!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildResultStat('Original', _compressionResult!.originalSizeFormatted),
                              _buildResultStat('Compressed', _compressionResult!.compressedSizeFormatted, isHighlight: true),
                              _buildResultStat('Saved', '${_compressionResult!.compressionRatio.toStringAsFixed(1)}%'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => OpenFile.open(_compressionResult!.outputPath),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Open'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _shareFile,
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A80F0),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridPreset(CompressionQuality quality, String label, IconData icon, Color color) {
    final isSelected = _selectedQuality == quality;
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    return GestureDetector(
      onTap: () {
        setState(() => _selectedQuality = quality);
        _updateEstimate();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.15) 
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2E2E2E)
                  : Colors.white),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
            color: isSelected ? color : (Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade600
                : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all((isLarge ? 12 : 10) * scale),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: (isLarge ? 32 : 26) * scale),
            ),
            SizedBox(height: 6 * scale),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: (isLarge ? 15 : 13) * scale,
                color: isSelected 
                    ? color 
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.grey[700]),
              ),
            ),
            if (isSelected)
              Padding(
                padding: EdgeInsets.only(top: 4 * scale),
                child: Icon(Icons.check_circle, color: color, size: (isLarge ? 20 : 16) * scale),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(
          fontSize: 12, 
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFB0BEC5)
              : Colors.grey[600],
        )),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isHighlight ? Colors.green[700] : null,
          ),
        ),
      ],
    );
  }
}

