import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';

enum AnnotationTool { none, draw, text, rectangle, circle, line, arrow }

class AnnotateScreen extends StatefulWidget {
  const AnnotateScreen({super.key});

  @override
  State<AnnotateScreen> createState() => _AnnotateScreenState();
}

class _AnnotateScreenState extends State<AnnotateScreen> {
  File? _selectedFile;
  String? _fileName;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _savedFilePath;
  
  PdfDocument? _pdfDocument;
  int _currentPage = 1;
  int _totalPages = 0;
  PdfPageImage? _currentPageImage;
  Size _pageSize = Size.zero;
  Size _displaySize = Size.zero;
  
  AnnotationTool _currentTool = AnnotationTool.none;
  Color _annotationColor = Colors.red;
  double _strokeWidth = 3.0;
  
  Map<int, List<Annotation>> _pageAnnotations = {};
  
  // For freehand drawing
  Annotation? _currentDrawing;
  
  // Pending annotation (shape/text) waiting for position confirmation
  Annotation? _pendingAnnotation;
  
  List<UndoAction> _undoStack = [];
  List<UndoAction> _redoStack = [];

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        await _loadPdf(File(result.files.first.path!), result.files.first.name);
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPdf(File file, String fileName) async {
    try {
      _pdfDocument?.close();
      final doc = await PdfDocument.openFile(file.path);
      setState(() {
        _selectedFile = file;
        _fileName = fileName;
        _pdfDocument = doc;
        _totalPages = doc.pagesCount;
        _currentPage = 1;
        _pageAnnotations.clear();
        _undoStack.clear();
        _redoStack.clear();
        _savedFilePath = null;
        _currentTool = AnnotationTool.none;
        _pendingAnnotation = null;
      });
      await _loadPageImage();
    } catch (e) {
      _showError('Error loading PDF: $e');
    }
  }

  Future<void> _loadPageImage() async {
    if (_pdfDocument == null) return;
    try {
      final page = await _pdfDocument!.getPage(_currentPage);
      final pageImage = await page.render(width: page.width * 2, height: page.height * 2, format: PdfPageImageFormat.png);
      await page.close();
      setState(() {
        _currentPageImage = pageImage;
        _pageSize = Size((pageImage?.width ?? 0).toDouble(), (pageImage?.height ?? 0).toDouble());
      });
    } catch (e) {
      _showError('Error rendering page: $e');
    }
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() {
      _currentPage = page;
      _currentPageImage = null;
      _currentDrawing = null;
      _pendingAnnotation = null;
    });
    await _loadPageImage();
  }

  void _setTool(AnnotationTool tool) {
    setState(() {
      _currentTool = tool;
      _currentDrawing = null;
      _pendingAnnotation = null;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    final annotations = _pageAnnotations[action.page];
    if (annotations != null && annotations.isNotEmpty) {
      final removed = annotations.removeLast();
      _redoStack.add(UndoAction(page: action.page, annotation: removed));
      setState(() {});
    }
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final action = _redoStack.removeLast();
    _pageAnnotations.putIfAbsent(action.page, () => []);
    _pageAnnotations[action.page]!.add(action.annotation);
    _undoStack.add(action);
    setState(() {});
  }

  void _clearAll() {
    setState(() {
      _pageAnnotations.clear();
      _undoStack.clear();
      _redoStack.clear();
      _currentDrawing = null;
      _pendingAnnotation = null;
    });
  }

  // --- Drawing handlers ---
  void _onDrawStart(Offset pos) {
    setState(() {
      _currentDrawing = Annotation(
        type: AnnotationTool.draw,
        color: _annotationColor,
        strokeWidth: _strokeWidth,
        points: [pos],
        startPoint: pos,
        endPoint: pos,
      );
    });
  }

  void _onDrawUpdate(Offset pos) {
    if (_currentDrawing == null) return;
    setState(() => _currentDrawing!.points.add(pos));
  }

  void _onDrawEnd() {
    if (_currentDrawing == null || _currentDrawing!.points.length < 2) {
      setState(() => _currentDrawing = null);
      return;
    }
    _addAnnotation(_currentDrawing!);
    setState(() => _currentDrawing = null);
  }

  // --- Shape creation ---
  void _createShape(AnnotationTool type, Offset start, Offset end) {
    setState(() {
      _pendingAnnotation = Annotation(
        type: type,
        color: _annotationColor,
        strokeWidth: _strokeWidth,
        points: [],
        startPoint: start,
        endPoint: end,
      );
    });
  }

  void _onShapeDragStart(Offset pos) {
    // Create shape with initial size
    final end = Offset(pos.dx + 100, pos.dy + 80);
    _createShape(_currentTool, pos, end);
  }

  void _onShapeDragUpdate(Offset delta) {
    if (_pendingAnnotation == null) return;
    setState(() {
      _pendingAnnotation = _pendingAnnotation!.move(delta, _displaySize);
    });
  }

  void _onResizeTopLeft(Offset delta) {
    if (_pendingAnnotation == null) return;
    setState(() {
      final newStart = Offset(
        (_pendingAnnotation!.startPoint.dx + delta.dx).clamp(0, _pendingAnnotation!.endPoint.dx - 30),
        (_pendingAnnotation!.startPoint.dy + delta.dy).clamp(0, _pendingAnnotation!.endPoint.dy - 30),
      );
      _pendingAnnotation = Annotation(type: _pendingAnnotation!.type, color: _pendingAnnotation!.color, strokeWidth: _pendingAnnotation!.strokeWidth, points: [], startPoint: newStart, endPoint: _pendingAnnotation!.endPoint, text: _pendingAnnotation!.text);
    });
  }

  void _onResizeTopRight(Offset delta) {
    if (_pendingAnnotation == null) return;
    setState(() {
      final newEnd = Offset(
        (_pendingAnnotation!.endPoint.dx + delta.dx).clamp(_pendingAnnotation!.startPoint.dx + 30, _displaySize.width),
        _pendingAnnotation!.endPoint.dy,
      );
      final newStart = Offset(
        _pendingAnnotation!.startPoint.dx,
        (_pendingAnnotation!.startPoint.dy + delta.dy).clamp(0, _pendingAnnotation!.endPoint.dy - 30),
      );
      _pendingAnnotation = Annotation(type: _pendingAnnotation!.type, color: _pendingAnnotation!.color, strokeWidth: _pendingAnnotation!.strokeWidth, points: [], startPoint: newStart, endPoint: newEnd, text: _pendingAnnotation!.text);
    });
  }

  void _onResizeBottomLeft(Offset delta) {
    if (_pendingAnnotation == null) return;
    setState(() {
      final newStart = Offset(
        (_pendingAnnotation!.startPoint.dx + delta.dx).clamp(0, _pendingAnnotation!.endPoint.dx - 30),
        _pendingAnnotation!.startPoint.dy,
      );
      final newEnd = Offset(
        _pendingAnnotation!.endPoint.dx,
        (_pendingAnnotation!.endPoint.dy + delta.dy).clamp(_pendingAnnotation!.startPoint.dy + 30, _displaySize.height),
      );
      _pendingAnnotation = Annotation(type: _pendingAnnotation!.type, color: _pendingAnnotation!.color, strokeWidth: _pendingAnnotation!.strokeWidth, points: [], startPoint: newStart, endPoint: newEnd, text: _pendingAnnotation!.text);
    });
  }

  void _onResizeBottomRight(Offset delta) {
    if (_pendingAnnotation == null) return;
    setState(() {
      final newEnd = Offset(
        (_pendingAnnotation!.endPoint.dx + delta.dx).clamp(_pendingAnnotation!.startPoint.dx + 30, _displaySize.width),
        (_pendingAnnotation!.endPoint.dy + delta.dy).clamp(_pendingAnnotation!.startPoint.dy + 30, _displaySize.height),
      );
      _pendingAnnotation = Annotation(type: _pendingAnnotation!.type, color: _pendingAnnotation!.color, strokeWidth: _pendingAnnotation!.strokeWidth, points: [], startPoint: _pendingAnnotation!.startPoint, endPoint: newEnd, text: _pendingAnnotation!.text);
    });
  }

  List<Widget> _buildResizablePendingAnnotation() {
    if (_pendingAnnotation == null) return [];
    
    final a = _pendingAnnotation!;
    final left = a.startPoint.dx;
    final top = a.startPoint.dy;
    final width = (a.endPoint.dx - a.startPoint.dx).abs();
    final height = (a.endPoint.dy - a.startPoint.dy).abs();
    final centerX = left + width / 2;
    final centerY = top + height / 2;
    const handleSize = 16.0;
    const rotateHandleOffset = 30.0;
    
    // Calculate rotated corner positions
    Offset rotatePoint(double x, double y) {
      final dx = x - centerX;
      final dy = y - centerY;
      final cos = math.cos(a.rotation);
      final sin = math.sin(a.rotation);
      return Offset(
        centerX + dx * cos - dy * sin,
        centerY + dx * sin + dy * cos,
      );
    }
    
    final topLeft = rotatePoint(left, top);
    final topRight = rotatePoint(left + width, top);
    final bottomLeft = rotatePoint(left, top + height);
    final bottomRight = rotatePoint(left + width, top + height);
    final rotateHandlePos = rotatePoint(centerX, top - rotateHandleOffset - handleSize / 2);
    
    return [
      // Main shape (draggable + rotated)
      Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          onPanUpdate: (d) => _onShapeDragUpdate(d.delta),
          child: Transform.rotate(
            angle: a.rotation,
            alignment: Alignment.center,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue, width: 2)),
              child: CustomPaint(painter: PendingAnnotationPainter(annotation: a)),
            ),
          ),
        ),
      ),
      // Rotation handle (follows rotation)
      Positioned(
        left: rotateHandlePos.dx - handleSize / 2,
        top: rotateHandlePos.dy - handleSize / 2,
        child: GestureDetector(
          onPanUpdate: (d) => _onRotate(d.localPosition, Offset(centerX, centerY)),
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            child: const Icon(Icons.rotate_right, size: 12, color: Colors.white),
          ),
        ),
      ),
      // Top-left handle (rotated)
      Positioned(
        left: topLeft.dx - handleSize / 2,
        top: topLeft.dy - handleSize / 2,
        child: GestureDetector(
          onPanUpdate: (d) => _onResizeTopLeft(d.delta),
          child: Container(width: handleSize, height: handleSize, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3))),
        ),
      ),
      // Top-right handle (rotated)
      Positioned(
        left: topRight.dx - handleSize / 2,
        top: topRight.dy - handleSize / 2,
        child: GestureDetector(
          onPanUpdate: (d) => _onResizeTopRight(d.delta),
          child: Container(width: handleSize, height: handleSize, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3))),
        ),
      ),
      // Bottom-left handle (rotated)
      Positioned(
        left: bottomLeft.dx - handleSize / 2,
        top: bottomLeft.dy - handleSize / 2,
        child: GestureDetector(
          onPanUpdate: (d) => _onResizeBottomLeft(d.delta),
          child: Container(width: handleSize, height: handleSize, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3))),
        ),
      ),
      // Bottom-right handle (rotated)
      Positioned(
        left: bottomRight.dx - handleSize / 2,
        top: bottomRight.dy - handleSize / 2,
        child: GestureDetector(
          onPanUpdate: (d) => _onResizeBottomRight(d.delta),
          child: Container(width: handleSize, height: handleSize, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3))),
        ),
      ),
    ];
  }

  void _onRotate(Offset localPos, Offset center) {
    if (_pendingAnnotation == null) return;
    // Calculate angle from center to touch point
    final a = _pendingAnnotation!;
    final shapeCenter = Offset(
      (a.startPoint.dx + a.endPoint.dx) / 2,
      (a.startPoint.dy + a.endPoint.dy) / 2,
    );
    // Use global position relative to shape center
    final touchY = a.startPoint.dy - 30 - 8 + localPos.dy; // Approx touch position
    final touchX = shapeCenter.dx + localPos.dx - 8;
    final angle = math.atan2(touchX - shapeCenter.dx, shapeCenter.dy - touchY);
    setState(() {
      _pendingAnnotation = a.copyWith(rotation: angle);
    });
  }



  // --- Text creation ---
  Future<void> _onTextTap(Offset pos) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Enter text...', border: OutlineInputBorder()), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Add')),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      // Calculate text box size based on text length
      final textWidth = math.max(100.0, result.length * 10.0);
      final textHeight = 40.0;
      final clampedEnd = Offset(
        (pos.dx + textWidth).clamp(0, _displaySize.width),
        (pos.dy + textHeight).clamp(0, _displaySize.height),
      );
      setState(() {
        _pendingAnnotation = Annotation(
          type: AnnotationTool.text,
          color: _annotationColor,
          strokeWidth: _strokeWidth,
          points: [],
          startPoint: pos,
          endPoint: clampedEnd,
          text: result,
        );
      });
    }
  }

  // --- Confirm/Cancel pending ---
  void _confirmPending() {
    if (_pendingAnnotation != null) {
      _addAnnotation(_pendingAnnotation!);
      setState(() => _pendingAnnotation = null);
    }
  }

  void _cancelPending() {
    setState(() => _pendingAnnotation = null);
  }

  void _addAnnotation(Annotation annotation) {
    _pageAnnotations.putIfAbsent(_currentPage, () => []);
    _pageAnnotations[_currentPage]!.add(annotation);
    _undoStack.add(UndoAction(page: _currentPage, annotation: annotation));
    _redoStack.clear();
    setState(() {});
  }

  Future<void> _saveAnnotatedPdf() async {
    if (_selectedFile == null) return;
    setState(() => _isSaving = true);
    
    try {
      final bytes = await _selectedFile!.readAsBytes();
      final document = sf_pdf.PdfDocument(inputBytes: bytes);
      
      for (final entry in _pageAnnotations.entries) {
        final pageIndex = entry.key - 1;
        if (pageIndex >= 0 && pageIndex < document.pages.count) {
          final page = document.pages[pageIndex];
          final scaleX = page.size.width / _displaySize.width;
          final scaleY = page.size.height / _displaySize.height;
          
          for (final a in entry.value) {
            final pen = sf_pdf.PdfPen(sf_pdf.PdfColor(a.color.red, a.color.green, a.color.blue), width: a.strokeWidth * scaleX);
            final brush = sf_pdf.PdfSolidBrush(sf_pdf.PdfColor(a.color.red, a.color.green, a.color.blue));
            
            // Apply rotation for shapes (not freehand)
            if (a.rotation != 0 && a.type != AnnotationTool.draw) {
              final centerX = ((a.startPoint.dx + a.endPoint.dx) / 2) * scaleX;
              final centerY = ((a.startPoint.dy + a.endPoint.dy) / 2) * scaleY;
              page.graphics.save();
              page.graphics.translateTransform(centerX, centerY);
              page.graphics.rotateTransform(a.rotation * 180 / math.pi); // Convert to degrees
              page.graphics.translateTransform(-centerX, -centerY);
            }
            
            switch (a.type) {
              case AnnotationTool.draw:
                for (int i = 0; i < a.points.length - 1; i++) {
                  page.graphics.drawLine(pen, Offset(a.points[i].dx * scaleX, a.points[i].dy * scaleY), Offset(a.points[i + 1].dx * scaleX, a.points[i + 1].dy * scaleY));
                }
                break;
              case AnnotationTool.text:
                final boxHeight = (a.endPoint.dy - a.startPoint.dy).abs();
                final fontSize = (boxHeight * 0.6).clamp(10.0, 100.0) * scaleY;
                final font = sf_pdf.PdfStandardFont(sf_pdf.PdfFontFamily.helvetica, fontSize);
                page.graphics.drawString(a.text ?? '', font, brush: brush, bounds: Rect.fromLTWH(a.startPoint.dx * scaleX + 4, a.startPoint.dy * scaleY + (boxHeight * scaleY - fontSize) / 2, 0, 0));
                break;
              case AnnotationTool.rectangle:
                page.graphics.drawRectangle(pen: pen, bounds: Rect.fromPoints(Offset(a.startPoint.dx * scaleX, a.startPoint.dy * scaleY), Offset(a.endPoint.dx * scaleX, a.endPoint.dy * scaleY)));
                break;
              case AnnotationTool.circle:
                page.graphics.drawEllipse(Rect.fromPoints(Offset(a.startPoint.dx * scaleX, a.startPoint.dy * scaleY), Offset(a.endPoint.dx * scaleX, a.endPoint.dy * scaleY)), pen: pen);
                break;
              case AnnotationTool.line:
                page.graphics.drawLine(pen, Offset(a.startPoint.dx * scaleX, a.startPoint.dy * scaleY), Offset(a.endPoint.dx * scaleX, a.endPoint.dy * scaleY));
                break;
              case AnnotationTool.arrow:
                final start = Offset(a.startPoint.dx * scaleX, a.startPoint.dy * scaleY);
                final end = Offset(a.endPoint.dx * scaleX, a.endPoint.dy * scaleY);
                page.graphics.drawLine(pen, start, end);
                final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
                final arrowSize = 15.0 * scaleX;
                page.graphics.drawLine(pen, end, Offset(end.dx - arrowSize * math.cos(angle - 0.5), end.dy - arrowSize * math.sin(angle - 0.5)));
                page.graphics.drawLine(pen, end, Offset(end.dx - arrowSize * math.cos(angle + 0.5), end.dy - arrowSize * math.sin(angle + 0.5)));
                break;
              default:
                break;
            }
            
            // Restore graphics if rotation was applied
            if (a.rotation != 0 && a.type != AnnotationTool.draw) {
              page.graphics.restore();
            }
          }
        }
      }
      
      final savedBytes = await document.save();
      document.dispose();
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = _fileName?.replaceAll('.pdf', '') ?? 'annotated';
      final outputFileName = '${baseName}_annotated_$timestamp.pdf';
      final documentsDir = await getApplicationDocumentsDirectory();
      final outputPath = '${documentsDir.path}/$outputFileName';
      await File(outputPath).writeAsBytes(savedBytes);
      
      setState(() {
        _savedFilePath = outputPath;
        _pageAnnotations.clear();
        _undoStack.clear();
        _redoStack.clear();
      });
      
      await _loadPdf(File(outputPath), outputFileName);
      await HistoryUtils.addToHistory(context: context, fileName: outputFileName, toolName: 'PDF Annotate', toolId: 'annotate', filePath: outputPath);
      _showSuccess('Saved!');
      
      // Show interstitial ad after successful operation
      AdService().showInterstitialAfterOperation();
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_savedFilePath == null) await _saveAnnotatedPdf();
    if (_savedFilePath != null) await Share.shareXFiles([XFile(_savedFilePath!)]);
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Color & Stroke', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [Colors.red, Colors.blue, Colors.green, Colors.black, Colors.orange, Colors.purple]
                  .map((c) => GestureDetector(
                        onTap: () { setState(() => _annotationColor = c); Navigator.pop(ctx); },
                        child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _annotationColor == c ? Colors.white : Colors.grey, width: _annotationColor == c ? 3 : 1))),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text('Stroke: ${_strokeWidth.toInt()}'),
            Slider(value: _strokeWidth, min: 1, max: 15, divisions: 14, onChanged: (v) => setState(() => _strokeWidth = v)),
          ],
        ),
      ),
    );
  }

  void _showShapesPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Shape', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShapeOption(ctx, Icons.rectangle_outlined, 'Rectangle', AnnotationTool.rectangle),
                _buildShapeOption(ctx, Icons.circle_outlined, 'Circle', AnnotationTool.circle),
                _buildShapeOption(ctx, Icons.remove, 'Line', AnnotationTool.line),
                _buildShapeOption(ctx, Icons.arrow_forward, 'Arrow', AnnotationTool.arrow),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShapeOption(BuildContext ctx, IconData icon, String label, AnnotationTool tool) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        _setTool(tool);
        Navigator.pop(ctx);
        // Auto-create shape at center
        final center = Offset(_displaySize.width / 2 - 50, _displaySize.height / 2 - 40);
        _createShape(tool, center, Offset(center.dx + 100, center.dy + 80));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3E3E3E) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: isDark ? Colors.white70 : Colors.grey.shade700),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getContentScale(context);
    return BaseScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Annotate'),
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
            IconButton(icon: const Icon(Icons.help_outline), onPressed: () => HelpDialog.show(context, 'annotate'), tooltip: 'Help'),
            if (_pdfDocument != null) ...[
              IconButton(icon: const Icon(Icons.palette), onPressed: _showColorPicker, tooltip: 'Color'),
              IconButton(icon: const Icon(Icons.undo), onPressed: _undoStack.isEmpty ? null : _undo, tooltip: 'Undo'),
              IconButton(icon: const Icon(Icons.redo), onPressed: _redoStack.isEmpty ? null : _redo, tooltip: 'Redo'),
              IconButton(icon: Icon(_isSaving ? Icons.hourglass_empty : Icons.save), onPressed: _isSaving ? null : _saveAnnotatedPdf, tooltip: 'Save'),
              IconButton(icon: const Icon(Icons.share), onPressed: _isSaving ? null : _sharePdf, tooltip: 'Share'),
            ],
          ],
        ),
        body: _pdfDocument == null ? _buildPickerView() : _buildAnnotateView(),
      ),
    );
  }

  Widget _buildPickerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF2E3A59), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF4A80F0), width: 2)),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PDF Annotate', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Draw, write, add shapes', style: TextStyle(color: Color(0xFFA0B4D9))),
                ])),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.edit_note, color: Colors.white, size: 28)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildFeature(Icons.draw, 'Draw', Colors.red),
                      _buildFeature(Icons.text_fields, 'Text', Colors.blue),
                      _buildFeature(Icons.category, 'Shapes', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickPdf,
                      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
                      label: Text(_isLoading ? 'Loading...' : 'Select PDF'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String label, Color color) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10)),
    ]);
  }

  Widget _buildAnnotateView() {
    final currentAnnotations = _pageAnnotations[_currentPage] ?? [];
    final isShapeTool = _currentTool == AnnotationTool.rectangle || _currentTool == AnnotationTool.circle || _currentTool == AnnotationTool.line || _currentTool == AnnotationTool.arrow;
    
    return Column(
      children: [
        // Page nav
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 1 && _pendingAnnotation == null ? () => _goToPage(_currentPage - 1) : null, iconSize: 20),
            Expanded(child: Center(child: Text('Page $_currentPage / $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold)))),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _currentPage < _totalPages && _pendingAnnotation == null ? () => _goToPage(_currentPage + 1) : null, iconSize: 20),
          ]),
        ),

        // Tools (disabled when pending)
        if (_pendingAnnotation == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTool(Icons.pan_tool, 'View', AnnotationTool.none),
                _buildTool(Icons.draw, 'Draw', AnnotationTool.draw),
                _buildTool(Icons.text_fields, 'Text', AnnotationTool.text),
                _buildShapesTool(),
                if (_pageAnnotations.isNotEmpty)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        Text('Clear', style: TextStyle(fontSize: 9, color: Colors.red)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),

        // Confirm/Cancel bar when pending
        if (_pendingAnnotation != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: _annotationColor.withOpacity(0.1), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]),
            child: Row(
              children: [
                const Icon(Icons.open_with, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Drag to position, then confirm', style: TextStyle(fontSize: 13))),
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: _cancelPending, tooltip: 'Cancel'),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _confirmPending,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
              ],
            ),
          ),

        // Canvas
        Expanded(
          child: _currentPageImage == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final imageRatio = _pageSize.width / _pageSize.height;
                    final containerRatio = constraints.maxWidth / constraints.maxHeight;
                    double displayWidth, displayHeight;
                    if (containerRatio > imageRatio) {
                      displayHeight = constraints.maxHeight;
                      displayWidth = displayHeight * imageRatio;
                    } else {
                      displayWidth = constraints.maxWidth;
                      displayHeight = displayWidth / imageRatio;
                    }
                    _displaySize = Size(displayWidth, displayHeight);
                    
                    return Center(
                      child: Container(
                        width: displayWidth,
                        height: displayHeight,
                        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: GestureDetector(
                            onPanStart: _currentTool == AnnotationTool.draw ? (d) => _onDrawStart(d.localPosition) : null,
                            onPanUpdate: _currentTool == AnnotationTool.draw ? (d) => _onDrawUpdate(d.localPosition) : null,
                            onPanEnd: _currentTool == AnnotationTool.draw ? (d) => _onDrawEnd() : null,
                            onTapUp: _currentTool == AnnotationTool.text ? (d) => _onTextTap(d.localPosition) : null,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(_currentPageImage!.bytes, fit: BoxFit.fill),
                                CustomPaint(painter: AnnotationPainter(annotations: currentAnnotations, currentDrawing: _currentDrawing)),
                                
                                // Pending annotation (draggable + resizable)
                                if (_pendingAnnotation != null)
                                  ..._buildResizablePendingAnnotation(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Mode indicator
        if (_currentTool != AnnotationTool.none && _pendingAnnotation == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: _annotationColor.withOpacity(0.1),
            child: Text(
              _currentTool == AnnotationTool.draw ? 'Draw on page' : _currentTool == AnnotationTool.text ? 'Tap to add text' : 'Select a shape from menu',
              textAlign: TextAlign.center,
              style: TextStyle(color: _annotationColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),

        if (_savedFilePath != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.green.withOpacity(0.15)
                : Colors.green.shade50,
            child: Row(children: [
              Icon(Icons.check_circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green
                    : Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved!',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.green.shade700,
                  ),
                ),
              ),
              TextButton(onPressed: () async => await OpenFile.open(_savedFilePath!), child: const Text('Open')),
            ]),
          ),
      ],
    );
  }

  Widget _buildTool(IconData icon, String label, AnnotationTool tool) {
    final isActive = _currentTool == tool;
    return GestureDetector(
      onTap: () => _setTool(tool),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _annotationColor.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: _annotationColor, width: 2) : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: isActive ? _annotationColor : Colors.grey, size: 20),
          Text(label, style: TextStyle(fontSize: 9, color: isActive ? _annotationColor : Colors.grey)),
        ]),
      ),
    );
  }

  Widget _buildShapesTool() {
    final isShapeActive = _currentTool == AnnotationTool.rectangle || _currentTool == AnnotationTool.circle || _currentTool == AnnotationTool.line || _currentTool == AnnotationTool.arrow;
    return GestureDetector(
      onTap: _showShapesPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isShapeActive ? _annotationColor.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(8),
          border: isShapeActive ? Border.all(color: _annotationColor, width: 2) : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.category, color: isShapeActive ? _annotationColor : Colors.grey, size: 20),
          Text('Shapes', style: TextStyle(fontSize: 9, color: isShapeActive ? _annotationColor : Colors.grey)),
        ]),
      ),
    );
  }
}

// Models
class Annotation {
  final AnnotationTool type;
  final Color color;
  final double strokeWidth;
  final List<Offset> points;
  final Offset startPoint;
  final Offset endPoint;
  final String? text;
  final double rotation; // Rotation angle in radians

  Annotation({required this.type, required this.color, required this.strokeWidth, required this.points, required this.startPoint, required this.endPoint, this.text, this.rotation = 0.0});

  Annotation move(Offset delta, Size bounds) {
    Offset clamp(Offset p) => Offset((p.dx + delta.dx).clamp(0, bounds.width), (p.dy + delta.dy).clamp(0, bounds.height));
    return Annotation(type: type, color: color, strokeWidth: strokeWidth, points: points.map(clamp).toList(), startPoint: clamp(startPoint), endPoint: clamp(endPoint), text: text, rotation: rotation);
  }

  Annotation copyWith({Offset? startPoint, Offset? endPoint, double? rotation}) {
    return Annotation(
      type: type,
      color: color,
      strokeWidth: strokeWidth,
      points: points,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      text: text,
      rotation: rotation ?? this.rotation,
    );
  }
}

class UndoAction {
  final int page;
  final Annotation annotation;
  UndoAction({required this.page, required this.annotation});
}

// Painters
class AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final Annotation? currentDrawing;

  AnnotationPainter({required this.annotations, this.currentDrawing});

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in annotations) _draw(canvas, a);
    if (currentDrawing != null) _draw(canvas, currentDrawing!);
  }

  void _draw(Canvas canvas, Annotation a) {
    final paint = Paint()..color = a.color..strokeWidth = a.strokeWidth..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    
    // Apply rotation if needed
    if (a.rotation != 0 && a.type != AnnotationTool.draw) {
      final centerX = (a.startPoint.dx + a.endPoint.dx) / 2;
      final centerY = (a.startPoint.dy + a.endPoint.dy) / 2;
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(a.rotation);
      canvas.translate(-centerX, -centerY);
    }
    
    switch (a.type) {
      case AnnotationTool.draw:
        if (a.points.length < 2) return;
        final path = ui.Path()..moveTo(a.points.first.dx, a.points.first.dy);
        for (int i = 1; i < a.points.length; i++) path.lineTo(a.points[i].dx, a.points[i].dy);
        canvas.drawPath(path, paint);
        break;
      case AnnotationTool.text:
        final boxHeight = (a.endPoint.dy - a.startPoint.dy).abs();
        final fontSize = (boxHeight * 0.6).clamp(10.0, 100.0);
        TextPainter(
          text: TextSpan(text: a.text ?? '', style: TextStyle(color: a.color, fontSize: fontSize, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: (a.endPoint.dx - a.startPoint.dx).abs())..paint(canvas, Offset(a.startPoint.dx + 4, a.startPoint.dy + (boxHeight - fontSize) / 2));
        break;
      case AnnotationTool.rectangle:
        canvas.drawRect(Rect.fromPoints(a.startPoint, a.endPoint), paint);
        break;
      case AnnotationTool.circle:
        canvas.drawOval(Rect.fromPoints(a.startPoint, a.endPoint), paint);
        break;
      case AnnotationTool.line:
        canvas.drawLine(a.startPoint, a.endPoint, paint);
        break;
      case AnnotationTool.arrow:
        canvas.drawLine(a.startPoint, a.endPoint, paint);
        final angle = math.atan2(a.endPoint.dy - a.startPoint.dy, a.endPoint.dx - a.startPoint.dx);
        canvas.drawLine(a.endPoint, Offset(a.endPoint.dx - 15 * math.cos(angle - 0.5), a.endPoint.dy - 15 * math.sin(angle - 0.5)), paint);
        canvas.drawLine(a.endPoint, Offset(a.endPoint.dx - 15 * math.cos(angle + 0.5), a.endPoint.dy - 15 * math.sin(angle + 0.5)), paint);
        break;
      default:
        break;
    }
    
    // Restore canvas if rotation was applied
    if (a.rotation != 0 && a.type != AnnotationTool.draw) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PendingAnnotationPainter extends CustomPainter {
  final Annotation annotation;
  PendingAnnotationPainter({required this.annotation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = annotation.color..strokeWidth = annotation.strokeWidth..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final selectionPaint = Paint()..color = Colors.blue..strokeWidth = 2..style = PaintingStyle.stroke;
    
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect.inflate(3), selectionPaint); // Selection border
    
    switch (annotation.type) {
      case AnnotationTool.text:
        // Scale font size based on container height
        final fontSize = (size.height * 0.6).clamp(10.0, 100.0);
        TextPainter(
          text: TextSpan(text: annotation.text ?? '', style: TextStyle(color: annotation.color, fontSize: fontSize, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width)..paint(canvas, Offset(4, (size.height - fontSize) / 2));
        break;
      case AnnotationTool.rectangle:
        canvas.drawRect(rect, paint);
        break;
      case AnnotationTool.circle:
        canvas.drawOval(rect, paint);
        break;
      case AnnotationTool.line:
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        break;
      case AnnotationTool.arrow:
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
        final angle = math.atan2(size.height, size.width);
        canvas.drawLine(Offset(size.width, size.height), Offset(size.width - 15 * math.cos(angle - 0.5), size.height - 15 * math.sin(angle - 0.5)), paint);
        canvas.drawLine(Offset(size.width, size.height), Offset(size.width - 15 * math.cos(angle + 0.5), size.height - 15 * math.sin(angle + 0.5)), paint);
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
