import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovepdf_flutter/models/pdf_tool.dart';
import 'package:ilovepdf_flutter/widgets/tool_card.dart';
import 'package:ilovepdf_flutter/widgets/search_bar_widget.dart';
import 'package:ilovepdf_flutter/widgets/category_tabs_widget.dart';
import 'package:ilovepdf_flutter/widgets/recent_files_widget.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:provider/provider.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/banner_ad_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  int _selectedCategory = 0;
  final List<String> _categories = ['All', 'Edit', 'Convert', 'Organize', 'Forms'];
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Start stagger animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  List<PdfTool> get _filteredTools {
    var tools = pdfTools.toList();

    // Filter by category
    if (_selectedCategory > 0) {
      final categoryName = _categories[_selectedCategory].toLowerCase();
      tools = tools.where((t) => t.category == categoryName).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      tools = tools.where((t) =>
          t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query)).toList();
    }

    return tools;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredTools = _filteredTools;

    return BaseScreen(
      canPop: false,
      showBannerAd: false, // Has own bottomNavigationBar ad
      child: Scaffold(
        bottomNavigationBar: const BottomBannerAd(),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Compact App Bar with gradient
              SliverAppBar(
                expandedHeight: 110,
                floating: false,
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF4A80F0),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E1E1E), const Color(0xFF2E3A59)]
                            : [const Color(0xFF4A80F0), const Color(0xFF6B5CF5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background pattern
                        Positioned(
                          right: -30,
                          top: -30,
                          child: Icon(
                            Icons.description,
                            size: 120,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 35, 20, 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'PDF Hub',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Consumer<AppSettings>(
                                      builder: (context, settings, _) => Text(
                                        settings.userName.isNotEmpty
                                            ? 'Welcome, ${settings.userName}!'
                                            : 'Your Complete PDF Toolkit',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 11,
                                          fontFamily: 'Poppins',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded, color: Colors.white, size: 18),
                    ),
                    onPressed: () => context.go('/history'),
                    tooltip: 'History',
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                    ),
                    onPressed: () => context.go('/settings'),
                    tooltip: 'Settings',
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: SearchBarWidget(
                  onSearch: (query) => setState(() => _searchQuery = query),
                  hintText: 'Search ${pdfTools.length} PDF tools...',
                ),
              ),

              // Recent Files (only show if no search query)
              if (_searchQuery.isEmpty)
                const SliverToBoxAdapter(
                  child: RecentFilesWidget(),
                ),

              // Category Tabs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: CategoryTabsWidget(
                    categories: _categories,
                    selectedIndex: _selectedCategory,
                    onCategorySelected: (index) => setState(() => _selectedCategory = index),
                  ),
                ),
              ),

              // Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A80F0), Color(0xFF6B5CF5)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedCategory == 0 ? 'All Tools' : _categories[_selectedCategory],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: isDark ? Colors.white : const Color(0xFF2E3A59),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A80F0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${filteredTools.length} tools',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4A80F0),
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tools Grid with staggered animation
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveUtils.getHorizontalPadding(context), 
                  0, 
                  ResponsiveUtils.getHorizontalPadding(context), 
                  20
                ),
                sliver: filteredTools.isEmpty
                    ? SliverToBoxAdapter(
                        child: _buildEmptySearchState(isDark),
                      )
                    : SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: ResponsiveUtils.getGridColumns(context),
                          childAspectRatio: ResponsiveUtils.getCardAspectRatio(context),
                          crossAxisSpacing: ResponsiveUtils.getGridSpacing(context),
                          mainAxisSpacing: ResponsiveUtils.getGridSpacing(context),
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tool = filteredTools[index];

                            return AnimatedBuilder(
                              animation: _staggerController,
                              builder: (context, child) {
                                final delay = index * 0.1;
                                final startTime = delay.clamp(0.0, 0.9);
                                final endTime = (startTime + 0.3).clamp(0.0, 1.0);

                                final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _staggerController,
                                    curve: Interval(startTime, endTime, curve: Curves.easeOut),
                                  ),
                                );

                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.3),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: ToolCard(
                                tool: tool,
                                index: index,
                                showBadge: tool.isNew,
                                badgeText: tool.isNew ? 'NEW' : null,
                                onTap: () => context.go(tool.route),
                              ),
                            );
                          },
                          childCount: filteredTools.length,
                        ),
                      ),
              ),

              // Footer padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No tools found',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}