import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';

// ─── screen ───────────────────────────────────────────────────────────────────

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // ── File state ───────────────────────────────────────────────────────────────
  File? _selectedFile;
  String _fileName = '';
  int _pageCount = 0;
  int _currentPage = 1;

  // ── Viewer state ─────────────────────────────────────────────────────────────
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();
  final PdfViewerController _controller = PdfViewerController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();

  // ── UI toggles ───────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _nightMode = false;
  bool _showSearch = false;
  bool _showThumbnailBar = false;

  // ── Search ───────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  int _searchMatchCount = 0;
  int _searchCurrentMatch = 0;

  // ── Bookmarks ────────────────────────────────────────────────────────────────
  final Set<int> _bookmarks = {};

  // ── Jump to page ─────────────────────────────────────────────────────────────
  final TextEditingController _pageController = TextEditingController();

  bool _toolbarVisible = true;


  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── File picking ─────────────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        final f = result.files.first;
        if (f.path != null) {
          setState(() {
            _selectedFile = File(f.path!);
            _fileName = f.name;
            _pageCount = 0;
            _currentPage = 1;
            _bookmarks.clear();
            _searchResult.clear();
            _showSearch = false;
            _showThumbnailBar = false;
          });
        }
      }
    } catch (e) {
      _snack('Could not open file: $e', error: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Search ───────────────────────────────────────────────────────────────────

  void _runSearch(String query) {
    if (query.trim().isEmpty) {
      _searchResult.clear();
      setState(() {
        _searchMatchCount = 0;
        _searchCurrentMatch = 0;
      });
      return;
    }
    // Assign the controller's search result directly so next/prev work on it
    _searchResult = _controller.searchText(query);
    _searchResult.addListener(() {
      if (mounted) {
        setState(() {
          _searchMatchCount = _searchResult.totalInstanceCount;
          _searchCurrentMatch = _searchResult.currentInstanceIndex;
        });
      }
    });
  }

  void _searchNext() {
    _searchResult.nextInstance();
    setState(() => _searchCurrentMatch = _searchResult.currentInstanceIndex);
  }

  void _searchPrev() {
    _searchResult.previousInstance();
    setState(() => _searchCurrentMatch = _searchResult.currentInstanceIndex);
  }

  // ── Bookmark ─────────────────────────────────────────────────────────────────

  void _toggleBookmark() {
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
        _snack('Bookmark removed');
      } else {
        _bookmarks.add(_currentPage);
        _snack('Page $_currentPage bookmarked');
      }
    });
  }

  // ── Share ────────────────────────────────────────────────────────────────────

  Future<void> _sharePdf() async {
    if (_selectedFile == null) return;
    await Share.shareXFiles([XFile(_selectedFile!.path)], text: _fileName);
  }

  // ── Page thumbnail info overlay ───────────────────────────────────────────────

  void _showJumpToPage() {
    _pageController.text = '$_currentPage';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Go to Page',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '1 – $_pageCount',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.book_outlined),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A80F0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final pg = int.tryParse(_pageController.text.trim());
              if (pg != null && pg >= 1 && pg <= _pageCount) {
                _controller.jumpToPage(pg);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  // ── Toolbar toggle ────────────────────────────────────────────────────────────

  void _toggleToolbar() {
    setState(() => _toolbarVisible = !_toolbarVisible);
  }

  // ── Snack ─────────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : const Color(0xFF4A80F0),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Bookmarks sheet ───────────────────────────────────────────────────────────

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BookmarksSheet(
        bookmarks: _bookmarks,
        currentPage: _currentPage,
        onJumpTo: (pg) {
          _controller.jumpToPage(pg);
          Navigator.pop(context);
        },
        onRemove: (pg) {
          setState(() => _bookmarks.remove(pg));
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BaseScreen(
      child: Scaffold(
        backgroundColor:
            _nightMode ? const Color(0xFF121212) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        body: _selectedFile == null
            ? _buildLandingView(isDark)
            : _buildViewerView(isDark),
      ),
    );
  }

  // ── Landing view (no file selected) ──────────────────────────────────────────

  Widget _buildLandingView(bool isDark) {
    return SafeArea(
      child: Column(
        children: [
          // AppBar substitute
          _NavBar(
            title: 'PDF Reader',
            isDark: isDark,
            actions: const [],
            onBack: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Hero card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PDF Reader',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins')),
                              const SizedBox(height: 6),
                              Text(
                                'Read, search & bookmark\nyour PDF documents',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13,
                                    fontFamily: 'Poppins'),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.menu_book_rounded,
                              color: Colors.white, size: 40),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Pick button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickPdf,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(_isLoading ? 'Opening…' : 'Open PDF File'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins'),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Feature grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: const [
                      _FeatureTile(
                          icon: Icons.search_rounded,
                          color: Color(0xFF1565C0),
                          label: 'Full-Text Search'),
                      _FeatureTile(
                          icon: Icons.bookmark_rounded,
                          color: Color(0xFFF57C00),
                          label: 'Bookmarks'),
                      _FeatureTile(
                          icon: Icons.nightlight_round,
                          color: Color(0xFF6A1B9A),
                          label: 'Night Mode'),
                      _FeatureTile(
                          icon: Icons.zoom_in_rounded,
                          color: Color(0xFF00838F),
                          label: 'Pinch to Zoom'),
                      _FeatureTile(
                          icon: Icons.view_agenda_rounded,
                          color: Color(0xFF2E7D32),
                          label: 'Thumbnail Panel'),
                      _FeatureTile(
                          icon: Icons.share_rounded,
                          color: Color(0xFFC62828),
                          label: 'Share PDF'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Viewer view (file selected) ────────────────────────────────────────────

  Widget _buildViewerView(bool isDark) {
    final isBookmarked = _bookmarks.contains(_currentPage);

    return SafeArea(
      child: Column(
        children: [
          // ── Top AppBar (animated height) ─────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            height: _toolbarVisible ? kToolbarHeight + 12 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: _NavBar(
              title: _fileName,
              isDark: isDark,
              nightMode: _nightMode,
              onBack: () => setState(() {
                _selectedFile = null;
                _searchResult.clear();
              }),
              actions: [
                // Bookmark toggle
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isBookmarked ? Colors.amber : Colors.white,
                  ),
                  tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark page',
                  onPressed: _toggleBookmark,
                ),
                // Bookmarks list (only when any exist)
                if (_bookmarks.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.bookmarks_rounded, color: Colors.white),
                    tooltip: 'View bookmarks',
                    onPressed: _showBookmarksSheet,
                  ),
                // Search
                IconButton(
                  icon: Icon(
                    _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Search',
                  onPressed: () => setState(() => _showSearch = !_showSearch),
                ),
                // More menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: _onMenuSelected,
                  itemBuilder: (_) => [
                    _menuItem('night_mode',
                        _nightMode ? 'Day Mode' : 'Night Mode',
                        _nightMode ? Icons.wb_sunny_rounded : Icons.nightlight_round),
                    _menuItem('thumbnails',
                        _showThumbnailBar ? 'Hide Thumbnails' : 'Show Thumbnails',
                        Icons.view_sidebar_rounded),
                    _menuItem('jump', 'Go to Page', Icons.input_rounded),
                    _menuItem('share', 'Share PDF', Icons.share_rounded),
                    _menuItem('change', 'Open Another PDF', Icons.swap_horiz_rounded),
                  ],
                ),
              ],
            ),
          ),

          // ── Search bar ──────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            height: _showSearch ? 56 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: _SearchBar(
              controller: _searchController,
              resultCount: _searchMatchCount,
              currentMatch: _searchCurrentMatch,
              nightMode: _nightMode,
              onSearch: _runSearch,
              onNext: _searchNext,
              onPrev: _searchPrev,
              onClose: () {
                _searchResult.clear();
                _searchController.clear();
                setState(() {
                  _showSearch = false;
                  _searchMatchCount = 0;
                  _searchCurrentMatch = 0;
                });
              },
            ),
          ),

          // ── Main content row ─────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // Thumbnail sidebar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: _showThumbnailBar ? 80 : 0,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: _showThumbnailBar
                      ? _ThumbnailSidebar(
                          pageCount: _pageCount,
                          currentPage: _currentPage,
                          nightMode: _nightMode,
                          onPageTap: (pg) => _controller.jumpToPage(pg),
                        )
                      : const SizedBox.shrink(),
                ),

                // PDF Viewer
                Expanded(
                  child: GestureDetector(
                    onTap: _toggleToolbar,
                    behavior: HitTestBehavior.translucent,
                    child: ColorFiltered(
                      colorFilter: _nightMode
                          ? const ColorFilter.matrix([
                              -1, 0, 0, 0, 255,
                               0,-1, 0, 0, 255,
                               0, 0,-1, 0, 255,
                               0, 0, 0, 1,   0,
                            ])
                          : const ColorFilter.matrix([
                              1, 0, 0, 0, 0,
                              0, 1, 0, 0, 0,
                              0, 0, 1, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                      child: SfPdfViewer.file(
                        _selectedFile!,
                        key: _viewerKey,
                        controller: _controller,
                        canShowScrollHead: true,
                        canShowScrollStatus: true,
                        enableDoubleTapZooming: true,
                        enableTextSelection: true,
                        onDocumentLoaded: (details) {
                          setState(() {
                            _pageCount = details.document.pages.count;
                            _currentPage = 1;
                          });
                        },
                        onPageChanged: (details) {
                          setState(() => _currentPage = details.newPageNumber);
                        },
                        onDocumentLoadFailed: (details) {
                          _snack('Failed to load: ${details.error}', error: true);
                          setState(() => _selectedFile = null);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom bar (animated height) ─────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            height: _toolbarVisible ? 48 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: _BottomBar(
              currentPage: _currentPage,
              pageCount: _pageCount,
              nightMode: _nightMode,
              onZoomIn: () => _controller.zoomLevel =
                  (_controller.zoomLevel + 0.25).clamp(0.5, 5.0),
              onZoomOut: () => _controller.zoomLevel =
                  (_controller.zoomLevel - 0.25).clamp(0.5, 5.0),
              onPrev: () => _controller.jumpToPage(
                  (_currentPage - 1).clamp(1, _pageCount)),
              onNext: () => _controller.jumpToPage(
                  (_currentPage + 1).clamp(1, _pageCount)),
              onJump: _showJumpToPage,
            ),
          ),
        ],
      ),
    );
  }

  // ── Menu handling ──────────────────────────────────────────────────────────

  void _onMenuSelected(String value) {
    switch (value) {
      case 'night_mode':
        setState(() => _nightMode = !_nightMode);
        break;
      case 'thumbnails':
        setState(() => _showThumbnailBar = !_showThumbnailBar);
        break;
      case 'jump':
        _showJumpToPage();
        break;
      case 'share':
        _sharePdf();
        break;
      case 'change':
        _pickPdf();
        break;
    }
  }

  PopupMenuItem<String> _menuItem(String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF4A80F0)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontFamily: 'Poppins')),
      ]),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final String title;
  final bool isDark;
  final bool nightMode;
  final VoidCallback onBack;
  final List<Widget> actions;

  const _NavBar({
    required this.title,
    required this.isDark,
    this.nightMode = false,
    required this.onBack,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final bg = nightMode
        ? const Color(0xFF1A1A2E)
        : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFF1565C0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: bg,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions.map((a) => IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: a,
              )),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int resultCount;
  final int currentMatch;
  final bool nightMode;
  final ValueChanged<String> onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.resultCount,
    required this.currentMatch,
    required this.nightMode,
    required this.onSearch,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg = nightMode ? const Color(0xFF1A1A2E) : const Color(0xFF1565C0);
    return Container(
      color: bg.withValues(alpha: 0.95),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search in document…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: InputBorder.none,
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white70),
              ),
              onSubmitted: onSearch,
              onChanged: onSearch,
            ),
          ),
          if (resultCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$currentMatch / $resultCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
              onPressed: onPrev),
          IconButton(
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              onPressed: onNext),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final bool nightMode;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onJump; // tap page counter → dialog

  const _BottomBar({
    required this.currentPage,
    required this.pageCount,
    required this.nightMode,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = nightMode
        ? const Color(0xFF1A1A2E)
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F4FF));
    final canPrev = currentPage > 1;
    final canNext = pageCount > 0 && currentPage < pageCount;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      // Use IntrinsicHeight to keep bar tight, no unconstrained expansion
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          // ← Prev
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous page',
            iconSize: 26,
            onPressed: canPrev ? onPrev : null,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // Page counter — expands to fill remaining space
          Expanded(
            child: GestureDetector(
              onTap: onJump,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pageCount > 0 ? '$currentPage / $pageCount' : '───',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // → Next
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next page',
            iconSize: 26,
            onPressed: canNext ? onNext : null,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // Divider
          Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
          // Zoom out
          IconButton(
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Zoom out',
            iconSize: 22,
            onPressed: onZoomOut,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // Zoom in
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Zoom in',
            iconSize: 22,
            onPressed: onZoomIn,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailSidebar extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final bool nightMode;
  final ValueChanged<int> onPageTap;

  const _ThumbnailSidebar({
    required this.pageCount,
    required this.currentPage,
    required this.nightMode,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = nightMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5F5);
    return Container(
      width: 80,
      color: bg,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pageCount,
        itemBuilder: (ctx, i) {
          final pg = i + 1;
          final isActive = pg == currentPage;
          return GestureDetector(
            onTap: () => onPageTap(pg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF1565C0)
                      : Colors.transparent,
                  width: 2,
                ),
                color: isActive
                    ? const Color(0xFF1565C0).withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: Column(
                children: [
                  // Placeholder thumbnail
                  Container(
                    height: 70,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Icon(Icons.description_outlined,
                          color: Colors.grey, size: 24),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$pg',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? const Color(0xFF1565C0)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BookmarksSheet extends StatelessWidget {
  final Set<int> bookmarks;
  final int currentPage;
  final ValueChanged<int> onJumpTo;
  final ValueChanged<int> onRemove;

  const _BookmarksSheet({
    required this.bookmarks,
    required this.currentPage,
    required this.onJumpTo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = bookmarks.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bookmarks_rounded, color: Color(0xFF1565C0)),
            const SizedBox(width: 10),
            const Text('Bookmarks',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${sorted.length} pages',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
          const SizedBox(height: 16),
          ...sorted.map((pg) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1565C0),
                  radius: 18,
                  child: Text('$pg',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text('Page $pg',
                    style: const TextStyle(fontFamily: 'Poppins')),
                subtitle: pg == currentPage
                    ? const Text('Current page',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF1565C0)))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded,
                          color: Color(0xFF1565C0), size: 20),
                      onPressed: () => onJumpTo(pg),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: () => onRemove(pg),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _FeatureTile(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF2E3A59))),
        ],
      ),
    );
  }
}
