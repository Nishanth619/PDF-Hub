import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ilovepdf_flutter/services/pdf_merger_service.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';

enum SplitMode { pages, chunks, ranges, extract, delete, reverse }

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  File? _selectedPDF;
  PdfInfo? _pdfInfo;
  List<Uint8List> _pageThumbnails = [];
  Set<int> _selectedPages = {}; // 1-indexed
  bool _isLoading = false;
  bool _isLoadingThumbnails = false;
  double _progress = 0.0;
  List<String> _outputPaths = [];
  SplitMode _splitMode = SplitMode.extract;
  int _chunkSize = 2;
  final List<TextEditingController> _pageControllers = [];
  final List<TextEditingController> _rangeStartControllers = [];
  final List<TextEditingController> _rangeEndControllers = [];
  final List<PageRange> _ranges = [PageRange(startPage: 1, endPage: 1)];

  @override
  void initState() {
    super.initState();
    _pageControllers.add(TextEditingController());
    _rangeStartControllers.add(TextEditingController());
    _rangeEndControllers.add(TextEditingController());
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        // Validate file size (50MB limit)
        int fileSizeInBytes = await file.length();
        double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        
        if (fileSizeInMB > 50) {
          _showError('File size exceeds 50MB. Please select a smaller file.');
          return;
        }

        setState(() {
          _selectedPDF = file;
          _outputPaths = [];
          _progress = 0.0;
          _pdfInfo = null;
          _pageThumbnails = [];
          _selectedPages = {};
          _isLoadingThumbnails = true;
        });
        
        // Load PDF info and thumbnails
        await _loadPdfInfo();
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }
  
  Future<void> _loadPdfInfo() async {
    if (_selectedPDF == null) return;
    
    try {
      // Get PDF info first (fast)
      final info = await PdfSplitter.getPdfInfo(_selectedPDF!.path);
      setState(() => _pdfInfo = info);
      
      // Then load thumbnails (slower)
      final thumbnails = await PdfSplitter.getPageThumbnails(_selectedPDF!.path, dpi: 50.0);
      setState(() {
        _pageThumbnails = thumbnails;
        _isLoadingThumbnails = false;
      });
    } catch (e) {
      setState(() => _isLoadingThumbnails = false);
      _showError('Error loading PDF info: $e');
    }
  }
  
  void _togglePage(int pageNum) {
    setState(() {
      if (_selectedPages.contains(pageNum)) {
        _selectedPages.remove(pageNum);
      } else {
        _selectedPages.add(pageNum);
      }
    });
  }
  
  void _selectAll() {
    if (_pdfInfo != null) {
      setState(() {
        _selectedPages = Set<int>.from(List.generate(_pdfInfo!.pageCount, (i) => i + 1));
      });
    }
  }
  
  void _deselectAll() {
    setState(() => _selectedPages = {});
  }
  
  void _selectOddPages() {
    if (_pdfInfo != null) {
      setState(() {
        _selectedPages = Set<int>.from(
          List.generate(_pdfInfo!.pageCount, (i) => i + 1).where((p) => p % 2 == 1)
        );
      });
    }
  }
  
  void _selectEvenPages() {
    if (_pdfInfo != null) {
      setState(() {
        _selectedPages = Set<int>.from(
          List.generate(_pdfInfo!.pageCount, (i) => i + 1).where((p) => p % 2 == 0)
        );
      });
    }
  }
  
  void _selectFirstHalf() {
    if (_pdfInfo != null) {
      final half = (_pdfInfo!.pageCount / 2).ceil();
      setState(() {
        _selectedPages = Set<int>.from(List.generate(half, (i) => i + 1));
      });
    }
  }
  
  void _selectLastHalf() {
    if (_pdfInfo != null) {
      final half = (_pdfInfo!.pageCount / 2).floor();
      setState(() {
        _selectedPages = Set<int>.from(
          List.generate(_pdfInfo!.pageCount - half, (i) => half + i + 1)
        );
      });
    }
  }

  Future<void> _splitPDF() async {
    if (_selectedPDF == null) {
      _showError('Please select a PDF file');
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _outputPaths = [];
    });

    try {
      List<String> outputPaths = [];
      
      switch (_splitMode) {
        case SplitMode.pages:
          outputPaths = await PdfSplitter.splitIntoPages(
            pdfPath: _selectedPDF!.path,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          break;
          
        case SplitMode.chunks:
          outputPaths = await PdfSplitter.splitIntoChunks(
            pdfPath: _selectedPDF!.path,
            chunkSize: _chunkSize,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          break;
          
        case SplitMode.ranges:
          final List<PageRange> validRanges = [];
          for (int i = 0; i < _ranges.length; i++) {
            if (i < _rangeStartControllers.length && i < _rangeEndControllers.length) {
              final startText = _rangeStartControllers[i].text.trim();
              final endText = _rangeEndControllers[i].text.trim();
              if (startText.isNotEmpty && endText.isNotEmpty) {
                try {
                  final start = int.parse(startText);
                  final end = int.parse(endText);
                  if (start > 0 && end > 0 && start <= end) {
                    validRanges.add(PageRange(startPage: start, endPage: end));
                  }
                } catch (e) {}
              }
            }
          }
          if (validRanges.isEmpty) throw Exception('Please enter valid page ranges');
          
          outputPaths = await PdfSplitter.splitByRanges(
            pdfPath: _selectedPDF!.path,
            ranges: validRanges,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          break;
          
        case SplitMode.extract:
          // Use visual selection if available, otherwise use text fields
          List<int> pageNumbers;
          if (_selectedPages.isNotEmpty) {
            pageNumbers = _selectedPages.toList()..sort();
          } else {
            pageNumbers = [];
            for (var controller in _pageControllers) {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                try {
                  final pageNum = int.parse(text);
                  if (pageNum > 0) pageNumbers.add(pageNum);
                } catch (e) {}
              }
            }
          }
          
          if (pageNumbers.isEmpty) {
            throw Exception('Please select pages to extract');
          }
          
          final outputPath = await PdfSplitter.extractPages(
            pdfPath: _selectedPDF!.path,
            pageNumbers: pageNumbers,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          outputPaths = [outputPath];
          break;
          
        case SplitMode.delete:
          if (_selectedPages.isEmpty) {
            throw Exception('Please select pages to delete');
          }
          
          final deletePath = await PdfSplitter.removePages(
            pdfPath: _selectedPDF!.path,
            pageNumbers: _selectedPages.toList(),
            onProgress: (progress) => setState(() => _progress = progress),
          );
          outputPaths = [deletePath];
          break;
          
        case SplitMode.reverse:
          final reversePath = await PdfSplitter.reverseOrder(
            pdfPath: _selectedPDF!.path,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          outputPaths = [reversePath];
          break;
      }

      setState(() {
        _outputPaths = outputPaths;
        _isLoading = false;
        _progress = 1.0;
      });

      // Add to history for each output file
      for (final outputPath in outputPaths) {
        await HistoryUtils.addToHistory(
          context: context,
          fileName: outputPath.split('/').last,
          toolName: 'Split PDF',
          toolId: 'split',
          filePath: outputPath,
        );
      }

      _showSuccess('PDF split successfully!');
      
      // Show interstitial ad after successful operation
      AdService().showInterstitialAfterOperation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _progress = 0.0;
      });
      _showError('Split failed: $e');
    }
  }

  void _addPageField() {
    setState(() {
      _pageControllers.add(TextEditingController());
    });
  }

  void _addRangeField() {
    setState(() {
      _rangeStartControllers.add(TextEditingController());
      _rangeEndControllers.add(TextEditingController());
      _ranges.add(PageRange(startPage: 1, endPage: 1));
    });
  }

  void _removePageField(int index) {
    if (_pageControllers.length > 1) {
      setState(() {
        _pageControllers.removeAt(index);
      });
    }
  }

  void _removeRangeField(int index) {
    if (_rangeStartControllers.length > 1) {
      setState(() {
        _rangeStartControllers.removeAt(index);
        _rangeEndControllers.removeAt(index);
        _ranges.removeAt(index);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10),
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

  @override
  void dispose() {
    for (var controller in _pageControllers) {
      controller.dispose();
    }
    for (var controller in _rangeStartControllers) {
      controller.dispose();
    }
    for (var controller in _rangeEndControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getContentScale(context);
    return BaseScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Split PDF'),
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
              onPressed: () => HelpDialog.show(context, 'split'),
              tooltip: 'Help',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with distinctive design
                Container(
                  margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  padding: const EdgeInsets.all(20.0),
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
                              'Split PDF',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Extract specific pages from your PDF documents',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFE0E0E0)
                                    : const Color(0xFFA0B4D9),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select split method and configure options',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0BEC5)
                                    : const Color(0xFFC0D0E9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A80F0).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.call_split,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // PDF Selection Section
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
                
                // PDF Selection Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  width: double.infinity,
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
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _pickPDF,
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text('Select PDF'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          if (_selectedPDF != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2E3A59)
                                    : const Color(0xFF4A80F0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
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
                
                // PDF Info Display
                if (_selectedPDF != null && _pdfInfo != null) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A80F0), Color(0xFF3D6AE0)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(Icons.description, '${_pdfInfo!.pageCount}', 'Pages'),
                        _buildInfoItem(Icons.storage, _formatFileSize(_pdfInfo!.fileSize), 'Size'),
                        _buildInfoItem(Icons.check_circle, '${_selectedPages.length}', 'Selected'),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 8),

                // Split Mode Selection
                if (_selectedPDF != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                    child: Text(
                      'Select Split Method',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF2E3A59),
                            fontSize: 18,
                          ),
                    ),
                  ),
                  
                  // Split mode grid
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildModeCard(SplitMode.extract, Icons.checklist, 'Extract'),
                        _buildModeCard(SplitMode.delete, Icons.delete_outline, 'Delete'),
                        _buildModeCard(SplitMode.pages, Icons.view_module, 'All Pages'),
                        _buildModeCard(SplitMode.chunks, Icons.view_agenda, 'Chunks'),
                        _buildModeCard(SplitMode.ranges, Icons.linear_scale, 'Ranges'),
                        _buildModeCard(SplitMode.reverse, Icons.swap_vert, 'Reverse'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Visual Page Grid (for extract/delete modes)
                  if ((_splitMode == SplitMode.extract || _splitMode == SplitMode.delete) && _pdfInfo != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tap pages to ${_splitMode == SplitMode.extract ? "extract" : "delete"}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF2E3A59),
                                ),
                              ),
                              Text(
                                '${_selectedPages.length} / ${_pdfInfo!.pageCount}',
                                style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Quick select buttons
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildQuickButton('All', _selectAll),
                                _buildQuickButton('None', _deselectAll),
                                _buildQuickButton('Odd', _selectOddPages),
                                _buildQuickButton('Even', _selectEvenPages),
                                _buildQuickButton('First ½', _selectFirstHalf),
                                _buildQuickButton('Last ½', _selectLastHalf),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Page thumbnails grid
                          if (_isLoadingThumbnails)
                            const Center(child: CircularProgressIndicator())
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _pdfInfo!.pageCount,
                              itemBuilder: (context, index) {
                                final pageNum = index + 1;
                                final isSelected = _selectedPages.contains(pageNum);
                                return GestureDetector(
                                  onTap: () => _togglePage(pageNum),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF4A80F0) : Colors.grey.shade300,
                                        width: isSelected ? 3 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Stack(
                                      children: [
                                        if (index < _pageThumbnails.length)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.memory(
                                              _pageThumbnails[index],
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          )
                                        else
                                          Container(
                                            color: Colors.grey.shade200,
                                            child: const Center(child: Icon(Icons.picture_as_pdf, color: Colors.grey)),
                                          ),
                                        // Page number badge
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFF4A80F0) : Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$pageNum',
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        // Check icon for selected
                                        if (isSelected)
                                          const Positioned(
                                            top: 4,
                                            left: 4,
                                            child: Icon(Icons.check_circle, color: Color(0xFF4A80F0), size: 20),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Configuration based on selected mode
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getModeTitle(),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF2E3A59),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            if (_splitMode == SplitMode.chunks) ...[
                              Text(
                                'Pages per chunk: $_chunkSize',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFB0BEC5)
                                      : const Color(0xFF8F9BB3),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Slider(
                                value: _chunkSize.toDouble(),
                                min: 1,
                                max: 20,
                                divisions: 19,
                                label: _chunkSize.toString(),
                                onChanged: (value) {
                                  setState(() {
                                    _chunkSize = value.toInt();
                                  });
                                },
                              ),
                            ] else if (_splitMode == SplitMode.extract) ...[
                              Text(
                                'Enter page numbers to extract (comma separated)',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFB0BEC5)
                                      : const Color(0xFF8F9BB3),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(_pageControllers.length, (index) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _pageControllers[index],
                                          decoration: InputDecoration(
                                            labelText: 'Page ${index + 1}',
                                            border: const OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      if (_pageControllers.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: () => _removePageField(index),
                                        ),
                                    ],
                                  );
                                }),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addPageField,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Page'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A80F0),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ] else if (_splitMode == SplitMode.ranges) ...[
                              Text(
                                'Enter page ranges to extract',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFB0BEC5)
                                      : const Color(0xFF8F9BB3),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(_rangeStartControllers.length, (index) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _rangeStartControllers[index],
                                          decoration: const InputDecoration(
                                            labelText: 'Start Page',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _rangeEndControllers[index],
                                          decoration: const InputDecoration(
                                            labelText: 'End Page',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      if (_rangeStartControllers.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: () => _removeRangeField(index),
                                        ),
                                    ],
                                  );
                                }),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addRangeField,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Range'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A80F0),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Progress indicator
                  if (_isLoading) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
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
                          Text(
                            'Splitting PDF... ${( _progress * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF2E3A59),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Split Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _splitPDF,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF4A80F0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Split PDF',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  // Result Section
                  if (_outputPaths.isNotEmpty) ...[
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
                                'PDF Split Successfully!',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF2E3A59),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Generated ${_outputPaths.length} PDF files',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFB0BEC5)
                                      : const Color(0xFF8F9BB3),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // List of output files
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _outputPaths.length,
                                itemBuilder: (context, index) {
                                  final fileName = _outputPaths[index].split('/').last;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF2E3A59)
                                          : const Color(0xFF4A80F0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf,
                                          color: Color(0xFF4A80F0),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            fileName,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : const Color(0xFF2E3A59),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.open_in_new, size: 20),
                                          onPressed: () => OpenFile.open(_outputPaths[index]),
                                          tooltip: 'Open file',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF2E2E2E)
                                      : Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Tip: Files are saved in your device\'s temporary directory. Save them to a permanent location if needed.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    color: Color(0xFF8F9BB3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildModeOption(SplitMode mode, String title, String description) {
    final isSelected = _splitMode == mode;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _splitMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A80F0).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A80F0) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFF2E3A59),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF43A047),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String value, String label) {
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: (isLarge ? 30 : 24) * scale),
        SizedBox(height: 4 * scale),
        Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: (isLarge ? 22 : 18) * scale)),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: (isLarge ? 13 : 11) * scale)),
      ],
    );
  }
  
  Widget _buildModeCard(SplitMode mode, IconData icon, String label) {
    final isSelected = _splitMode == mode;
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    return GestureDetector(
      onTap: () => setState(() => _splitMode = mode),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : Colors.white,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4A80F0).withOpacity(0.3), blurRadius: 8)] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF4A80F0), size: (isLarge ? 28 : 22) * scale),
            SizedBox(width: 8 * scale),
            Flexible(
              child: Text(label, style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2E3A59),
                fontWeight: FontWeight.w600,
                fontSize: (isLarge ? 15 : 14) * scale,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickButton(String label, VoidCallback onTap) {
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    return Padding(
      padding: EdgeInsets.only(right: 8 * scale),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: const Color(0xFF2E3A59),
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: (isLarge ? 16 : 12) * scale, vertical: (isLarge ? 8 : 6) * scale),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * scale)),
        ),
        child: Text(label, style: TextStyle(fontSize: (isLarge ? 14 : 12) * scale)),
      ),
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  String _getModeTitle() {
    switch (_splitMode) {
      case SplitMode.pages:
        return 'Split Into Individual Pages';
      case SplitMode.chunks:
        return 'Split Into Chunks';
      case SplitMode.ranges:
        return 'Split By Page Ranges';
      case SplitMode.extract:
        return 'Extract Selected Pages';
      case SplitMode.delete:
        return 'Delete Selected Pages';
      case SplitMode.reverse:
        return 'Reverse Page Order';
    }
  }
}