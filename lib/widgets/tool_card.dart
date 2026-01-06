import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ilovepdf_flutter/models/pdf_tool.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'dart:ui';

class ToolCard extends StatefulWidget {
  final PdfTool tool;
  final VoidCallback onTap;
  final int index;
  final bool showBadge;
  final String? badgeText;

  const ToolCard({
    super.key,
    required this.tool,
    required this.onTap,
    this.index = 0,
    this.showBadge = false,
    this.badgeText,
  });

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive sizes - limit scaling to prevent overflow
    final rawScale = ResponsiveUtils.getContentScale(context);
    final scale = rawScale.clamp(1.0, 1.15); // Limit scaling to max 15%
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    final contentPadding = isLarge ? 14.0 : 12.0;
    final iconContainerPadding = isLarge ? 10.0 : 9.0;
    final iconSize = (isLarge ? 24.0 : 22.0) * scale;
    final titleSize = (isLarge ? 14.0 : 13.0) * scale;
    final descSize = (isLarge ? 10.0 : 10.0) * scale;
    
    // Parse gradient colors
    final gradientColors = widget.tool.gradientColors.map((colorString) {
      final hexCode = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    }).toList();

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(_isPressed ? 0.5 : 0.35),
                blurRadius: _isPressed ? 18 : 14,
                offset: Offset(0, _isPressed ? 8 : 6),
                spreadRadius: _isPressed ? 2 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Glassmorphism overlay
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Background pattern - aligned to bottom-right
                Positioned(
                  right: -18,
                  bottom: -18,
                  child: Icon(
                    _getToolIcon(widget.tool.id),
                    size: 75,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                // Shine effect
                Positioned(
                  top: -50,
                  left: -50,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Badge
                if (widget.showBadge && widget.badgeText != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.badgeText!,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: gradientColors.first,
                        ),
                      ),
                    ),
                  ),
                // Content
                Padding(
                  padding: EdgeInsets.all(contentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with enhanced glow effect
                      Container(
                        padding: EdgeInsets.all(iconContainerPadding),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.15),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          widget.tool.icon,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          width: iconSize,
                          height: iconSize,
                        ),
                      ),
                      SizedBox(height: isLarge ? 8.0 : 6.0),
                      // Title with shadow
                      Text(
                        widget.tool.title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Description
                      Text(
                        widget.tool.description,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.9),
                          fontSize: descSize,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getToolIcon(String toolId) {
    switch (toolId) {
      case 'compress': return Icons.compress;
      case 'merge': return Icons.merge_type;
      case 'split': return Icons.call_split;
      case 'rotate': return Icons.rotate_90_degrees_ccw;
      case 'watermark': return Icons.water_drop;
      case 'page_number': return Icons.format_list_numbered;
      case 'image_to_pdf': return Icons.image;
      case 'ocr': return Icons.document_scanner;
      case 'convert': return Icons.transform;
      case 'annotate': return Icons.edit_note;
      case 'form_filler': return Icons.edit_document;
      default: return Icons.description;
    }
  }
}