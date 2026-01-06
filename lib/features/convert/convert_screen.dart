import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:ilovepdf_flutter/services/pdf_converter_service.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';

enum ConversionType { image, word, excel, powerpoint, html }

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  // Single/Batch file selection
  List<File> _selectedPDFs = [];
  File? get _selectedPDF => _selectedPDFs.isNotEmpty ? _selectedPDFs.first : null;
  
  ConversionType? _selectedType;
  bool _isConverting = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _convertedFilePath;
  List<String> _convertedFilePaths = []; // For batch
  
  // Preview
  Uint8List? _previewImage;
  int _pageCount = 0;
  bool _isLoadingPreview = false;
  
  // Image quality DPI options
  int _selectedDpi = 150;
  final List<int> _dpiOptions = [72, 150, 300];
  
  final PDFConverterService _converterService = PDFConverterService();

  Future<void> _pickPDF({bool batch = false}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: batch,
      );

      if (result != null && result.files.isNotEmpty) {
        List<File> validFiles = [];
        
        for (final file in result.files) {
          if (file.path != null) {
            File pdfFile = File(file.path!);
            int fileSizeInBytes = await pdfFile.length();
            double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
            
            if (fileSizeInMB <= 50) {
              validFiles.add(pdfFile);
            }
          }
        }
        
        if (validFiles.isEmpty) {
          _showError('No valid PDF files selected (max 50MB each).');
          return;
        }

        setState(() {
          _selectedPDFs = validFiles;
          _convertedFilePath = null;
          _convertedFilePaths = [];
          _previewImage = null;
          _pageCount = 0;
          _statusMessage = batch 
            ? '${validFiles.length} PDF(s) selected'
            : 'PDF selected: ${validFiles.first.path.split('/').last}';
        });
        
        // Load preview for first file
        _loadPreview(validFiles.first);
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }
  
  Future<void> _loadPreview(File pdfFile) async {
    setState(() => _isLoadingPreview = true);
    
    try {
      final bytes = await pdfFile.readAsBytes();
      
      // Get page count
      final document = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      document.dispose();
      
      // Render first page as preview
      Uint8List? preview;
      await for (var page in Printing.raster(bytes, pages: [0], dpi: 72)) {
        preview = await page.toPng();
        break;
      }
      
      setState(() {
        _pageCount = pageCount;
        _previewImage = preview;
        _isLoadingPreview = false;
      });
    } catch (e) {
      setState(() => _isLoadingPreview = false);
    }
  }


  Future<void> _convertPDF() async {
    if (_selectedPDFs.isEmpty || _selectedType == null) {
      _showError('Please select a PDF and conversion type');
      return;
    }

    setState(() {
      _isConverting = true;
      _progress = 0.0;
      _statusMessage = 'Starting conversion...';
      _convertedFilePath = null;
      _convertedFilePaths = [];
    });

    try {
      final totalFiles = _selectedPDFs.length;
      List<String> allOutputPaths = [];
      
      for (int i = 0; i < totalFiles; i++) {
        final pdfFile = _selectedPDFs[i];
        final fileName = pdfFile.path.split('/').last;
        
        setState(() {
          _statusMessage = 'Converting file ${i + 1} of $totalFiles: $fileName';
        });
        
        String? outputPath;
        
        // Calculate base progress for this file
        final baseProgress = i / totalFiles;
        final fileProgressWeight = 1.0 / totalFiles;

        switch (_selectedType!) {
          case ConversionType.image:
            outputPath = await _converterService.convertToImage(
              pdfFile,
              dpi: _selectedDpi,
              onProgress: (progress, message) {
                setState(() {
                  _progress = baseProgress + (progress * fileProgressWeight);
                  _statusMessage = '[$fileName] $message';
                });
              },
            );
            break;
          case ConversionType.word:
            outputPath = await _converterService.convertToWord(
              pdfFile,
              onProgress: (progress, message) {
                setState(() {
                  _progress = baseProgress + (progress * fileProgressWeight);
                  _statusMessage = '[$fileName] $message';
                });
              },
            );
            break;
          case ConversionType.excel:
            outputPath = await _converterService.convertToExcel(
              pdfFile,
              onProgress: (progress, message) {
                setState(() {
                  _progress = baseProgress + (progress * fileProgressWeight);
                  _statusMessage = '[$fileName] $message';
                });
              },
            );
            break;
          case ConversionType.powerpoint:
            outputPath = await _converterService.convertToPowerPoint(
              pdfFile,
              onProgress: (progress, message) {
                setState(() {
                  _progress = baseProgress + (progress * fileProgressWeight);
                  _statusMessage = '[$fileName] $message';
                });
              },
            );
            break;
          case ConversionType.html:
            outputPath = await _converterService.convertToHtml(
              pdfFile,
              onProgress: (progress, message) {
                setState(() {
                  _progress = baseProgress + (progress * fileProgressWeight);
                  _statusMessage = '[$fileName] $message';
                });
              },
            );
            break;
        }
        
        if (outputPath != null) {
          allOutputPaths.add(outputPath);
        }
      }

      setState(() {
        _isConverting = false;
        _convertedFilePaths = allOutputPaths;
        _convertedFilePath = allOutputPaths.isNotEmpty ? allOutputPaths.last : null;
        _statusMessage = totalFiles > 1 
            ? '$totalFiles files converted successfully!'
            : 'Conversion completed successfully!';
      });
      
      // Add to history
      String toolName;
      String toolId;
      
      switch (_selectedType!) {
        case ConversionType.image:
          toolName = 'PDF to Image';
          toolId = 'convert_image';
          break;
        case ConversionType.word:
          toolName = 'PDF to Word';
          toolId = 'convert_word';
          break;
        case ConversionType.excel:
          toolName = 'PDF to Excel';
          toolId = 'convert_excel';
          break;
        case ConversionType.powerpoint:
          toolName = 'PDF to PowerPoint';
          toolId = 'convert_powerpoint';
          break;
        case ConversionType.html:
          toolName = 'PDF to HTML';
          toolId = 'convert_html';
          break;
      }
      
      // Add all converted files to history
      for (final outputPath in allOutputPaths) {
        await HistoryUtils.addToHistory(
          context: context,
          fileName: _getFileName(outputPath),
          toolName: toolName,
          toolId: toolId,
          filePath: outputPath,
        );
      }

      _showSuccess(totalFiles > 1 
          ? '$totalFiles files converted successfully!' 
          : 'File converted successfully!');
      
      // Show interstitial ad after successful operation
      AdService().showInterstitialAfterOperation();
    } catch (e) {
      setState(() {
        _isConverting = false;
        _statusMessage = 'Conversion failed';
      });
      _showError('Conversion failed: $e');
    }
  }

  Future<void> _openFile() async {
    if (_convertedFilePath == null) return;
    
    try {
      // Check if file exists
      final file = File(_convertedFilePath!);
      if (!await file.exists()) {
        _showError('File not found: ${_getFileName(_convertedFilePath!)}');
        return;
      }
      
      // Try to open the file
      final result = await OpenFile.open(_convertedFilePath);
      
      switch (result.type) {
        case ResultType.done:
          // File opened successfully
          _showSuccess('File opened successfully');
          break;
        case ResultType.error:
          _showError('Could not open file: ${result.message}');
          // Provide additional information to help user
          _showFileLocationInfo();
          break;
        case ResultType.fileNotFound:
          _showError('File not found');
          break;
        case ResultType.permissionDenied:
          _showError('Permission denied to open file');
          break;
        case ResultType.noAppToOpen:
          _showError('No app found to open this file type');
          // Provide additional information to help user
          _showFileLocationInfo();
          break;
        default:
          _showError('Could not open file: ${result.message}');
          // Provide additional information to help user
          _showFileLocationInfo();
      }
    } catch (e) {
      _showError('Error opening file: $e');
      // Provide additional information to help user
      _showFileLocationInfo();
    }
  }
  
  void _showFileLocationInfo() {
    // Show a snackbar with file location information
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File saved at:'),
            Text(_convertedFilePath!, style: const TextStyle(fontSize: 12)),
            const Text('You can manually open this file from your file manager.'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 15),
      ),
    );
  }

  Future<void> _shareFile() async {
    if (_convertedFilePaths.isEmpty) return;
    
    try {
      // Share all converted files
      List<XFile> filesToShare = [];
      for (final path in _convertedFilePaths) {
        final file = File(path);
        if (await file.exists()) {
          filesToShare.add(XFile(path));
        }
      }
      
      if (filesToShare.isNotEmpty) {
        await Share.shareXFiles(filesToShare);
      } else {
        _showError('No files found to share');
      }
    } catch (e) {
      _showError('Error sharing files: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10), // Show error for longer
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Conversion type data
  final List<Map<String, dynamic>> _conversionTypes = [
    {
      'type': ConversionType.image,
      'title': 'Image',
      'description': 'PNG',
      'icon': Icons.image,
      'color': const Color(0xFF4A80F0),
      'gradientColors': ['#4A80F0', '#1E88E5'],
    },
    {
      'type': ConversionType.word,
      'title': 'Word',
      'description': 'DOCX',
      'icon': Icons.description,
      'color': const Color(0xFF1E88E5),
      'gradientColors': ['#1E88E5', '#0D47A1'],
    },
    {
      'type': ConversionType.excel,
      'title': 'Excel',
      'description': 'XLSX',
      'icon': Icons.table_chart,
      'color': const Color(0xFF43A047),
      'gradientColors': ['#43A047', '#2E7D32'],
    },
    {
      'type': ConversionType.powerpoint,
      'title': 'PowerPoint',
      'description': 'PPTX',
      'icon': Icons.slideshow,
      'color': const Color(0xFFFFB300),
      'gradientColors': ['#FFB300', '#FF8F00'],
    },
    {
      'type': ConversionType.html,
      'title': 'HTML',
      'description': 'Web Page',
      'icon': Icons.code,
      'color': const Color(0xFFE91E63),
      'gradientColors': ['#E91E63', '#C2185B'],
    },
  ];

  Widget _buildConversionTypeCard(Map<String, dynamic> conversionType) {
    final isSelected = _selectedType == conversionType['type'];
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    
    // Parse gradient colors
    final gradientColors = conversionType['gradientColors'].map((colorString) {
      final hexCode = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    }).toList();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = conversionType['type'];
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * scale),
          gradient: LinearGradient(
            colors: isSelected 
                ? [gradientColors[0], gradientColors[1]] 
                : (Theme.of(context).brightness == Brightness.dark
                    ? [const Color(0xFF1E1E1E), const Color(0xFF2E2E2E)]
                    : [Colors.white, Colors.white]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isSelected 
                ? gradientColors[0] 
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF444444)
                    : const Color(0xFFE0E0E0)),
            width: 2,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all((isLarge ? 14.0 : 12.0) * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon container with circular background
              Container(
                padding: EdgeInsets.all((isLarge ? 10 : 8) * scale),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.2) 
                      : (Theme.of(context).brightness == Brightness.dark
                          ? conversionType['color'].withOpacity(0.2)
                          : conversionType['color'].withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
                child: Icon(
                  conversionType['icon'],
                  color: isSelected 
                      ? Colors.white 
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : conversionType['color']),
                  size: (isLarge ? 32 : 28) * scale,
                ),
              ),
              SizedBox(height: (isLarge ? 14 : 10) * scale),
              Text(
                conversionType['title'],
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isSelected 
                      ? Colors.white 
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF2E3A59)),
                  fontSize: (isLarge ? 17 : 15) * scale,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2 * scale),
              Text(
                conversionType['description'],
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isSelected 
                      ? Colors.white70 
                      : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3)),
                  fontSize: (isLarge ? 13 : 12) * scale,
                ),
              ),
              if (isSelected) ...[
                SizedBox(height: 4 * scale),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: (isLarge ? 22 : 18) * scale,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('PDF Converter'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => HelpDialog.show(context, 'convert'),
            tooltip: 'Help',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Simplified header section
              Container(
                margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3A59),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E3A59).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF4A80F0),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PDF Converter',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Convert your PDF files to various formats',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFE0E0E0)
                                  : const Color(0xFFA0B4D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80F0).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              
              // PDF Selection Section - FULL WIDTH
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  'Select PDF File',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF2E3A59),
                  ),
                ),
              ),
              
              // PDF Selection Card - FULL WIDTH
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                width: double.infinity, // Fill full width
                child: Card(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Preview or placeholder
                        if (_isLoadingPreview)
                          const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_previewImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _previewImage!,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          Icon(
                            Icons.picture_as_pdf,
                            size: 56,
                            color: _selectedPDF != null 
                                ? const Color(0xFF4A80F0) 
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0BEC5)
                                    : Colors.grey),
                          ),
                        
                        const SizedBox(height: 12),
                        
                        // Page count badge
                        if (_pageCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A80F0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_pageCount page${_pageCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF4A80F0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 12),
                        
                        // Single and Batch buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isConverting ? null : () => _pickPDF(batch: false),
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text('Select PDF'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isConverting ? null : () => _pickPDF(batch: true),
                                icon: const Icon(Icons.folder_open, size: 18),
                                label: const Text('Batch'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Batch file count
                        if (_selectedPDFs.length > 1) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF43A047).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF43A047)),
                            ),
                            child: Text(
                              '${_selectedPDFs.length} PDFs selected for batch conversion',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF43A047),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        
                        if (_selectedPDF != null && _selectedPDFs.length == 1) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF2E3A59)
                                  : const Color(0xFF4A80F0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _selectedPDF!.path.split('/').last,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF2E3A59),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // Conversion Type Selection
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                child: Text(
                  'Select Conversion Type',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF2E3A59),
                  ),
                ),
              ),
              
              // Grid layout for conversion types
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: null,
                      ),
                      itemCount: _conversionTypes.length,
                      itemBuilder: (context, index) {
                        return _buildConversionTypeCard(_conversionTypes[index]);
                      },
                    );
                  },
                ),
              ),
              
              // DPI Quality selector (only for Image type)
              if (_selectedType == ConversionType.image) ...[
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4A80F0).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.high_quality, color: Color(0xFF4A80F0), size: 20),
                          const SizedBox(width: 8),
                          Text('Image Quality (DPI)', style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2E3A59),
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _dpiOptions.map((dpi) {
                          final isSelected = _selectedDpi == dpi;
                          final label = dpi == 72 ? 'Low (72)' : dpi == 150 ? 'Medium (150)' : 'High (300)';
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedDpi = dpi),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF4A80F0) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : Colors.grey.withOpacity(0.3)),
                                ),
                                child: Text(label, textAlign: TextAlign.center, style: TextStyle(
                                  fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500,
                                  color: isSelected 
                                      ? Colors.white 
                                      : (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white70
                                          : null),
                                )),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),

              // Convert Button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                width: double.infinity, // Full width button
                child: ElevatedButton(
                  onPressed: (_selectedPDF != null && 
                             _selectedType != null && 
                             !_isConverting)
                      ? _convertPDF
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF4A80F0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isConverting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Convert PDF',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // Progress Indicator
              if (_isConverting) ...[
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A80F0)),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF2E3A59),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Result Section
              if (_convertedFilePaths.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    color: const Color(0xFF43A047).withOpacity(0.1),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: Color(0xFF43A047),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF43A047),
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _convertedFilePaths.length > 1 
                              ? '${_convertedFilePaths.length} Files Converted!'
                              : 'Conversion Completed!',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF2E3A59),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Show all converted files
                          ...List.generate(_convertedFilePaths.length, (index) {
                            final filePath = _convertedFilePaths[index];
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2E3A59)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF43A047),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${index + 1}. ${_getFileName(filePath)}',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : const Color(0xFF2E3A59),
                                      ),
                                    ),
                                  ),
                                  // Open button for each file
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xFF4A80F0)),
                                    onPressed: () async {
                                      try {
                                        await OpenFile.open(filePath);
                                      } catch (e) {
                                        _showError('Cannot open file');
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 14),
                          // Open and Share Buttons in a more prominent grid layout
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF2E3A59)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF4A80F0),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'What would you like to do?',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF2E3A59),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _openFile,
                                      icon: const Icon(Icons.open_in_new, size: 16),
                                      label: const Text('Open'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF43A047),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _shareFile,
                                      icon: const Icon(Icons.share, size: 16),
                                      label: const Text('Share'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4A80F0),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Show full path for reference
                                Container(
                                  width: double.infinity, // Full width container
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF2E2E2E)
                                        : Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Path: $_convertedFilePath',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 9,
                                      color: Color(0xFF8F9BB3),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tip: If "Open" doesn\'t work, manually locate the file.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9,
                                    color: Color(0xFF8F9BB3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
  }
  
  String _getFileName(String path) {
    return path.split('/').last;
  }
}