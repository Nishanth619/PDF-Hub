class PdfTool {
  final String id;
  final String title;
  final String description;
  final String icon;
  final List<String> gradientColors;
  final String route;
  final String category; // 'edit', 'convert', 'organize', 'forms'
  final bool isNew; // For "NEW" badge
  final bool webSupported; // Whether this tool works on web

  PdfTool({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.route,
    this.category = 'all',
    this.isNew = false,
    this.webSupported = false, // Default to not web-supported
  });
}

final List<PdfTool> pdfTools = [
  PdfTool(
    id: 'imagetopdf',
    title: 'Image to PDF',
    description: 'Convert images to PDF',
    icon: 'assets/icons/imagetopdf.svg',
    gradientColors: ['#E91E63', '#C2185B'],
    route: '/imagetopdf',
    category: 'convert',
    webSupported: true, // ✅ Web compatible
  ),
  PdfTool(
    id: 'annotate',
    title: 'Annotate',
    description: 'Highlight, draw & add notes',
    icon: 'assets/icons/annotate.svg',
    gradientColors: ['#FF9800', '#F57C00'],
    route: '/annotate',
    category: 'edit',
    webSupported: false, // ❌ Uses path_provider
  ),
  PdfTool(
    id: 'merge',
    title: 'Merge PDF',
    description: 'Combine multiple PDFs',
    icon: 'assets/icons/merge.svg',
    gradientColors: ['#43A047', '#2E7D32'],
    route: '/merge',
    category: 'organize',
    webSupported: true, // ✅ Web compatible
  ),
  PdfTool(
    id: 'split',
    title: 'Split PDF',
    description: 'Extract pages from PDF',
    icon: 'assets/icons/split.svg',
    gradientColors: ['#FF9800', '#F57C00'],
    route: '/split',
    category: 'organize',
    webSupported: true, // ✅ Web compatible
  ),
  PdfTool(
    id: 'compress',
    title: 'Compress',
    description: 'Reduce PDF file size',
    icon: 'assets/icons/compress.svg',
    gradientColors: ['#9C27B0', '#7B1FA2'],
    route: '/compress',
    category: 'organize',
    webSupported: true, // ✅ Web compatible
  ),
  PdfTool(
    id: 'rotate',
    title: 'Rotate',
    description: 'Rotate PDF pages',
    icon: 'assets/icons/rotate.svg',
    gradientColors: ['#00BCD4', '#0097A7'],
    route: '/rotate',
    category: 'edit',
    webSupported: true, // ✅ Web compatible
  ),
  PdfTool(
    id: 'watermark',
    title: 'Watermark',
    description: 'Add watermark to PDF',
    icon: 'assets/icons/watermark.svg',
    gradientColors: ['#607D8B', '#455A64'],
    route: '/watermark',
    category: 'edit',
    webSupported: false, // ❌ Uses path_provider
  ),
  PdfTool(
    id: 'pagenumber',
    title: 'Page Numbers',
    description: 'Add page numbers to PDF',
    icon: 'assets/icons/pagenumber.svg',
    gradientColors: ['#795548', '#5D4037'],
    route: '/pagenumber',
    category: 'edit',
    webSupported: false, // ❌ Uses path_provider
  ),
  PdfTool(
    id: 'ocr',
    title: 'OCR',
    description: 'Extract text from PDF',
    icon: 'assets/icons/ocr.svg',
    gradientColors: ['#6A11CB', '#2575FC'],
    route: '/ocr',
    category: 'convert',
    webSupported: false, // ❌ Uses ML Kit (mobile only)
  ),
  PdfTool(
    id: 'convert',
    title: 'Convert',
    description: 'PDF to Image, Word, Excel, PPT',
    icon: 'assets/icons/convert.svg',
    gradientColors: ['#4A80F0', '#1E88E5'],
    route: '/convert',
    category: 'convert',
    webSupported: false, // ❌ Uses path_provider
  ),
  PdfTool(
    id: 'formfiller',
    title: 'Form Filler',
    description: 'Fill interactive PDF forms',
    icon: 'assets/icons/form.svg',
    gradientColors: ['#FF6B6B', '#FF8E53'],
    route: '/formfiller',
    category: 'forms',
    webSupported: false, // ❌ Uses path_provider
  ),
  PdfTool(
    id: 'pdfviewer',
    title: 'PDF Reader',
    description: 'Read, search & bookmark PDFs',
    icon: 'assets/icons/annotate.svg', // reuse existing icon
    gradientColors: ['#1565C0', '#42A5F5'],
    route: '/pdfviewer',
    category: 'forms',
    isNew: true,
    webSupported: false, // ❌ Uses file system
  ),
];