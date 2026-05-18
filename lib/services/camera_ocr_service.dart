import 'dart:typed_data';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;
import 'package:ilovepdf_flutter/services/pdf_ocr_service.dart';
import 'package:image/image.dart' as img;

// ─── Isolate parameter/result holders ─────────────────────────────────────────
// These are plain Dart objects with no Flutter references — safe to send across
// isolate boundaries.

class _EnhanceParams {
  final Uint8List bytes;
  final int maxDimension; // cap before processing to prevent OOM
  final bool applyEnhancement; // if false, only resize (skip grayscale/sharpen)
  const _EnhanceParams(this.bytes, this.maxDimension,
      {this.applyEnhancement = true});
}

class _EnhanceResult {
  final Uint8List bytes;
  final bool enhanced;
  const _EnhanceResult(this.bytes, {this.enhanced = true});
}

// ─── Top-level (isolate-compatible) functions ──────────────────────────────────
// Must be top-level (not methods/closures) to be used with compute().

/// Run inside a background isolate: decode → resize → grayscale → contrast →
/// sharpen → encode PNG.  Returns the processed bytes.
_EnhanceResult _enhanceInIsolate(_EnhanceParams params) {
  try {
    var image = img.decodeImage(params.bytes);
    if (image == null) return _EnhanceResult(params.bytes, enhanced: false);

    // 1. Downscale to maxDimension if needed — prevents OOM on high-res cameras
    if (image.width > params.maxDimension ||
        image.height > params.maxDimension) {
      if (image.width >= image.height) {
        image = img.copyResize(image,
            width: params.maxDimension,
            interpolation: img.Interpolation.linear);
      } else {
        image = img.copyResize(image,
            height: params.maxDimension,
            interpolation: img.Interpolation.linear);
      }
    }

    img.Image processed;
    if (params.applyEnhancement) {
      // 2. Grayscale (reduces memory by 3×)
      processed = img.grayscale(image);
      // 3. Contrast + brightness boost
      processed = img.adjustColor(processed, contrast: 1.3, brightness: 1.05);
      // 4. Sharpening kernel
      processed = img.convolution(
        processed,
        filter: [0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0],
      );
    } else {
      processed = image; // resize only — no colour processing
    }

    // 5. Encode as PNG (lossless, ML Kit friendly)
    final outBytes = Uint8List.fromList(img.encodePng(processed, level: 6));
    return _EnhanceResult(outBytes);
  } catch (_) {
    // Any failure → return original bytes unmodified
    return _EnhanceResult(params.bytes, enhanced: false);
  }
}

// ─── Public service ────────────────────────────────────────────────────────────

/// Camera OCR service that keeps the UI thread free at 60 fps by offloading
/// all CPU-heavy image work to a background isolate via [compute].
class CameraOcrService {
  /// Maximum pixel dimension for the longer side before enhancement.
  /// 2048 gives excellent OCR accuracy while bounding memory use.
  static const int _maxDimension = 2048;

  // ── Main entry point ────────────────────────────────────────────────────────

  /// Extracts text from the image at [imagePath].
  ///
  /// Pipeline (all heavy work off the main thread):
  ///  1. Read file bytes          — awaited I/O (non-blocking)
  ///  2. Enhance in isolate       — [compute] → background thread
  ///  3. Write enhanced temp file — awaited I/O (non-blocking)
  ///  4. ML Kit processImage      — runs on native thread via platform channel
  ///  5. Parse results            — lightweight, stays on main thread
  static Future<OcrResult> extractTextFromImage({
    required String imagePath,
    mlkit.TextRecognitionScript script = mlkit.TextRecognitionScript.latin,
    bool enhance = true,
  }) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw FileSystemException('Image file not found', imagePath);
    }

    // ── Step 1: read bytes (async I/O — does not block UI) ──────────────────
    final rawBytes = await imageFile.readAsBytes();

    // ── Step 2: enhance in background isolate ─────────────────────────────
    String processPath = imagePath;
    bool createdTempFile = false;

    // Always run through the isolate: when enhance=true, apply full pipeline;
    // when enhance=false, just resize to prevent OOM in ML Kit.
    final result = await compute(
      _enhanceInIsolate,
      _EnhanceParams(rawBytes, _maxDimension,
          applyEnhancement: enhance),
    );

    if (result.enhanced) {
      // ── Step 3: write processed bytes to temp file (async I/O) ───────────
      final tempPath =
          '${imageFile.parent.path}/ocr_proc_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(result.bytes);
      processPath = tempPath;
      createdTempFile = true;
    }
    // If isolate processing failed, processPath stays as original — graceful fallback

    // ── Step 4: ML Kit OCR ──────────────────────────────────────────────────
    // ML Kit dispatches to a native thread internally — this await is non-blocking
    // for the UI thread.
    mlkit.TextRecognizer? recognizer;
    try {
      recognizer = mlkit.TextRecognizer(script: script);
      final inputImage = mlkit.InputImage.fromFilePath(processPath);
      final mlkitResult = await recognizer.processImage(inputImage);

      // ── Step 5: parse lightweight results (stays on main thread) ──────────
      return _buildOcrResult(mlkitResult);
    } finally {
      await recognizer?.close();
      // Cleanup temp file
      if (createdTempFile) {
        try {
          await File(processPath).delete();
        } catch (_) {}
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Converts ML Kit raw result into the app's [OcrResult] model.
  /// This is lightweight arithmetic — fine to run on main thread.
  static OcrResult _buildOcrResult(mlkit.RecognizedText mlkitResult) {
    final blocks = mlkitResult.blocks.map((block) {
      double confidence = 0.9;
      if (block.lines.isNotEmpty && block.lines.first.elements.isNotEmpty) {
        confidence = block.lines.first.elements.first.confidence ?? 0.9;
      }
      return TextBlock(
        text: block.text,
        confidence: confidence,
        boundingBox: block.boundingBox,
        lines: block.lines.map((l) => l.text).toList(),
      );
    }).toList();

    final pageText = PageText(
      pageNumber: 1,
      text: mlkitResult.text,
      blocks: blocks,
    );

    final wordCount = mlkitResult.text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    final avgConf = blocks.isNotEmpty
        ? blocks.map((b) => b.confidence).reduce((a, b) => a + b) /
            blocks.length
        : 0.0;

    return OcrResult(
      fullText: mlkitResult.text,
      pages: [pageText],
      pageCount: 1,
      wordCount: wordCount,
      averageConfidence: avgConf,
    );
  }
}
