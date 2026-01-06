import 'package:flutter/material.dart';

/// A reusable help dialog that explains how a feature works
class HelpDialog {
  /// Show help dialog for a specific tool
  static void show(BuildContext context, String toolId) {
    final help = _getHelpContent(toolId);
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Help',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curvedValue,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                constraints: const BoxConstraints(maxHeight: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [help.color, help.color.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(help.icon, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  help.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'How to use',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              help.description,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ...help.steps.asMap().entries.map((entry) => _buildStep(
                              entry.key + 1,
                              entry.value,
                              help.color,
                            )),
                            if (help.tips.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pro Tip',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.amber,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            help.tips,
                                            style: TextStyle(
                                              color: Colors.amber[800],
                                              fontSize: 12,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Footer button
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: help.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Got it!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildStep(int number, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _HelpContent _getHelpContent(String toolId) {
    switch (toolId) {
      case 'compress':
        return _HelpContent(
          title: 'Compress PDF',
          icon: Icons.compress,
          color: const Color(0xFFFF6B6B),
          description: 'Reduce PDF file size while maintaining quality. Perfect for email attachments and sharing.',
          steps: [
            'Select a PDF file from your device',
            'Choose compression level (Maximum, High, Medium, Low)',
            'Tap "Compress PDF" to start processing',
            'Open or share the compressed file',
          ],
          tips: 'Use Medium compression for the best balance between size and quality.',
        );
      case 'merge':
        return _HelpContent(
          title: 'Merge PDFs',
          icon: Icons.merge_type,
          color: const Color(0xFF4ECDC4),
          description: 'Combine multiple PDF files into a single document quickly and easily.',
          steps: [
            'Tap "Add PDFs" to select multiple files',
            'Drag to reorder files as needed',
            'Tap "Merge PDFs" to combine them',
            'Open or share the merged file',
          ],
          tips: 'Files are merged in the order shown. Drag to rearrange them.',
        );
      case 'split':
        return _HelpContent(
          title: 'Split PDF',
          icon: Icons.call_split,
          color: const Color(0xFF9B59B6),
          description: 'Extract specific pages or split a PDF into multiple smaller files.',
          steps: [
            'Select a PDF file',
            'Choose split mode (by pages, ranges, etc.)',
            'Specify which pages to extract',
            'Tap "Split PDF" to create new files',
          ],
          tips: 'Use ranges like "1-3, 5, 7-10" to select specific pages.',
        );
      case 'rotate':
        return _HelpContent(
          title: 'Rotate PDF',
          icon: Icons.rotate_90_degrees_ccw,
          color: const Color(0xFF2ECC71),
          description: 'Rotate pages in your PDF document to the correct orientation.',
          steps: [
            'Select a PDF file',
            'Tap pages to select them for rotation',
            'Choose rotation angle (90°, 180°, 270°)',
            'Tap "Rotate Pages" to apply changes',
          ],
          tips: 'Use "Select All" for quick selection of all pages.',
        );
      case 'watermark':
        return _HelpContent(
          title: 'Add Watermark',
          icon: Icons.water_drop,
          color: const Color(0xFF00BCD4),
          description: 'Add text watermarks to protect your PDF documents.',
          steps: [
            'Select a PDF file',
            'Enter your watermark text',
            'Choose position, color, and opacity',
            'Tap "Add Watermark" to apply',
          ],
          tips: 'Enable tiled pattern for full-page watermark coverage.',
        );
      case 'page_number':
        return _HelpContent(
          title: 'Page Numbers',
          icon: Icons.format_list_numbered,
          color: const Color(0xFF5C6BC0),
          description: 'Add page numbers to your PDF document with custom formatting.',
          steps: [
            'Select a PDF file',
            'Choose number format and position',
            'Customize color and font size',
            'Tap "Add Page Numbers" to apply',
          ],
          tips: 'The preview shows exactly how numbers will appear on pages.',
        );
      case 'image_to_pdf':
        return _HelpContent(
          title: 'Image to PDF',
          icon: Icons.image,
          color: const Color(0xFFE91E63),
          description: 'Convert images to PDF or scan documents using your camera.',
          steps: [
            'Select images from gallery or scan documents',
            'Drag to reorder images as needed',
            'Choose quality and page settings',
            'Tap "Convert to PDF" to create your document',
          ],
          tips: 'Long press and drag to reorder pages before conversion.',
        );
      case 'ocr':
        return _HelpContent(
          title: 'OCR Extractor',
          icon: Icons.document_scanner,
          color: const Color(0xFF3498DB),
          description: 'Extract text from scanned PDF documents using AI-powered OCR.',
          steps: [
            'Select a scanned PDF file',
            'Choose extraction mode (Fast/Balanced/Accurate)',
            'Select the language script',
            'Tap "Extract Text" to start OCR',
          ],
          tips: 'Use Balanced mode for the best speed/accuracy ratio.',
        );
      case 'convert':
        return _HelpContent(
          title: 'PDF Converter',
          icon: Icons.transform,
          color: const Color(0xFFF39C12),
          description: 'Convert PDF to various formats including images, Word, Excel, and more.',
          steps: [
            'Select a PDF file',
            'Choose your desired output format',
            'Adjust DPI for image conversion',
            'Tap "Convert" to start processing',
          ],
          tips: 'Higher DPI means better quality but larger file sizes.',
        );
      case 'annotate':
        return _HelpContent(
          title: 'Annotate PDF',
          icon: Icons.edit_note,
          color: const Color(0xFFE74C3C),
          description: 'Draw, write, and add shapes to your PDF documents.',
          steps: [
            'Select a PDF file',
            'Choose annotation tool (draw, text, shapes)',
            'Tap or drag on the page to annotate',
            'Save or share the annotated PDF',
          ],
          tips: 'Use the undo button to quickly remove mistakes.',
        );
      case 'form_filler':
        return _HelpContent(
          title: 'Form Filler',
          icon: Icons.edit_document,
          color: const Color(0xFF1ABC9C),
          description: 'Fill out PDF forms digitally without printing.',
          steps: [
            'Select a PDF form',
            'Tap on form fields to fill them',
            'Use keyboard to enter text',
            'Save the completed form',
          ],
          tips: 'Works best with standard PDF form fields.',
        );
      default:
        return _HelpContent(
          title: 'Help',
          icon: Icons.help,
          color: const Color(0xFF4A80F0),
          description: 'Learn how to use this feature.',
          steps: ['Select a file', 'Configure options', 'Process and save'],
          tips: '',
        );
    }
  }
}

class _HelpContent {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final List<String> steps;
  final String tips;

  _HelpContent({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.steps,
    required this.tips,
  });
}
