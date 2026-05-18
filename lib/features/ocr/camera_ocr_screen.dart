import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ilovepdf_flutter/services/camera_ocr_service.dart';
import 'package:ilovepdf_flutter/services/pdf_ocr_service.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';

/// Step enum that drives the UI state machine.
enum _ScanStep { idle, preview, processing, result }

class CameraOcrScreen extends StatefulWidget {
  const CameraOcrScreen({super.key});

  @override
  State<CameraOcrScreen> createState() => _CameraOcrScreenState();
}

class _CameraOcrScreenState extends State<CameraOcrScreen>
    with SingleTickerProviderStateMixin {
  _ScanStep _step = _ScanStep.idle;
  String? _capturedImagePath;
  OcrResult? _ocrResult;
  String? _savedFilePath;
  String _errorMessage = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.85, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── CAMERA / SCANNER ────────────────────────────────────────────────────────

  Future<void> _requestCameraAndScan() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isDenied || status.isPermanentlyDenied) {
      _showPermissionDialog();
      return;
    }

    // Try document scanner first (gives better edge-detection)
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 1,
        isGalleryImportAllowed: false,
      );
      if (pictures != null && pictures.isNotEmpty) {
        _onImageCaptured(pictures.first);
        return;
      }
    } catch (_) {
      // Fall through to image_picker
    }

    // Fallback: plain camera via image_picker
    try {
      final picker = ImagePicker();
      final xFile =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (xFile != null) {
        _onImageCaptured(xFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not open camera: $e');
      }
    }
  }

  void _onImageCaptured(String path) {
    setState(() {
      _capturedImagePath = path;
      _step = _ScanStep.preview;
      _ocrResult = null;
      _savedFilePath = null;
      _errorMessage = '';
    });
  }

  // ── OCR ─────────────────────────────────────────────────────────────────────

  Future<void> _runOcr() async {
    if (_capturedImagePath == null) return;
    setState(() {
      _step = _ScanStep.processing;
      _errorMessage = '';
    });

    try {
      final result = await CameraOcrService.extractTextFromImage(
        imagePath: _capturedImagePath!,
        enhance: true,
      );

      // Save as .txt
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'camera_ocr_$ts.txt';
      final outputPath = '${dir.path}/$fileName';
      await File(outputPath).writeAsString(result.fullText);

      if (!mounted) return;

      await HistoryUtils.addToHistory(
        context: context,
        fileName: fileName,
        toolName: 'Camera OCR Scan',
        toolId: 'ocr',
        filePath: outputPath,
      );

      setState(() {
        _ocrResult = result;
        _savedFilePath = outputPath;
        _step = _ScanStep.result;
      });

      AdService().showInterstitialAfterOperation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'OCR failed: $e';
        _step = _ScanStep.preview;
      });
    }
  }

  // ── ACTIONS ─────────────────────────────────────────────────────────────────

  void _copyToClipboard() {
    if (_ocrResult == null) return;
    Clipboard.setData(ClipboardData(text: _ocrResult!.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text copied to clipboard!')),
    );
  }

  void _shareFile() {
    if (_savedFilePath != null) {
      Share.shareXFiles([XFile(_savedFilePath!)],
          subject: 'OCR Scan Text');
    }
  }

  void _reset() {
    setState(() {
      _step = _ScanStep.idle;
      _capturedImagePath = null;
      _ocrResult = null;
      _savedFilePath = null;
      _errorMessage = '';
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
            'Camera access is needed to scan text. Please enable it in app settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1623) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF1A2035) : const Color(0xFF2E3A59),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Camera Scan OCR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        actions: [
          if (_step != _ScanStep.idle)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Scan again',
              onPressed: _reset,
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(isDark)),
    );
  }

  Widget _buildBody(bool isDark) {
    switch (_step) {
      case _ScanStep.idle:
        return _buildIdleView(isDark);
      case _ScanStep.preview:
        return _buildPreviewView(isDark);
      case _ScanStep.processing:
        return _buildProcessingView(isDark);
      case _ScanStep.result:
        return _buildResultView(isDark);
    }
  }

  // ── IDLE ────────────────────────────────────────────────────────────────────

  Widget _buildIdleView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hero camera illustration
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A80F0), Color(0xFF7B5EA7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A80F0).withValues(alpha: 0.45),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.document_scanner,
                    color: Colors.white, size: 60),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'Scan & Extract Text',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E2A49),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Point your camera at any document,\nbook, sign, or handwriting.\nMachine learning extracts the text instantly — fully offline.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _requestCameraAndScan,
                icon: const Icon(Icons.camera_alt, size: 22),
                label: const Text('Open Camera',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80F0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Feature chips
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _FeatureChip(icon: Icons.wifi_off, label: '100% Offline'),
                _FeatureChip(icon: Icons.bolt, label: 'Instant OCR'),
                _FeatureChip(icon: Icons.crop_rotate, label: 'Edge Detection'),
                _FeatureChip(icon: Icons.copy, label: 'Copy & Save'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── PREVIEW ─────────────────────────────────────────────────────────────────

  Widget _buildPreviewView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader('Step 2 – Review', Icons.image_search, isDark),
          const SizedBox(height: 16),
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(_capturedImagePath!),
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            _errorCard(_errorMessage, isDark),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _requestCameraAndScan,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Re-scan'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _runOcr,
                  icon: const Icon(Icons.text_snippet),
                  label: const Text('Extract Text'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF4A80F0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── PROCESSING ─────────────────────────────────────────────────────────────

  Widget _buildProcessingView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A80F0), Color(0xFF7B5EA7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A80F0).withValues(alpha: 0.4),
                      blurRadius: 24,
                    )
                  ],
                ),
                child: const Icon(Icons.auto_fix_high,
                    color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Extracting Text…',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E2A49),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ML Kit is analysing your image offline.\nThis usually takes less than 2 seconds.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF2E3A59),
              color: Color(0xFF4A80F0),
              minHeight: 6,
            ),
          ],
        ),
      ),
    );
  }

  // ── RESULT ──────────────────────────────────────────────────────────────────

  Widget _buildResultView(bool isDark) {
    final result = _ocrResult!;
    final hasText = result.fullText.trim().isNotEmpty;

    return Column(
      children: [
        // Stats bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E3A59), Color(0xFF1E2A49)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat(Icons.text_fields, '${result.wordCount}', 'words'),
              _vertDivider(),
              _stat(Icons.format_list_numbered, '${result.fullText.length}',
                  'chars'),
              _vertDivider(),
              _stat(Icons.thumb_up,
                  '${(result.averageConfidence * 100).toStringAsFixed(0)}%',
                  'confidence'),
            ],
          ),
        ),

        // Text area
        Expanded(
          child: hasText
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    result.fullText,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.65,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.text_fields_outlined,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No text detected',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try re-scanning with better lighting.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // Action bar
        SafeArea(
          top: false,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2035) : Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Row(
              children: [
                _actionButton(
                  icon: Icons.copy,
                  label: 'Copy',
                  color: const Color(0xFF4A80F0),
                  onTap: hasText ? _copyToClipboard : null,
                ),
                const SizedBox(width: 10),
                _actionButton(
                  icon: Icons.save_alt,
                  label: 'Save .txt',
                  color: Colors.green,
                  onTap: hasText ? _shareFile : null,
                ),
                const SizedBox(width: 10),
                _actionButton(
                  icon: Icons.camera_alt,
                  label: 'Scan Again',
                  color: Colors.orange,
                  onTap: _requestCameraAndScan,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────────

  Widget _buildStepHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4A80F0).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4A80F0), size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E2A49),
          ),
        ),
      ],
    );
  }

  Widget _errorCard(String msg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade400),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _vertDivider() => Container(
        width: 1,
        height: 40,
        color: Colors.white24,
      );

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: onTap != null ? color : color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── SMALL REUSABLE WIDGET ───────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2035) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF4A80F0).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4A80F0)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF2E3A59))),
        ],
      ),
    );
  }
}

