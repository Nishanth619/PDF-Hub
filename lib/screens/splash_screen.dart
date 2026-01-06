import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _topNodeAnim;
  late Animation<double> _leftNodeAnim;
  late Animation<double> _rightNodeAnim;
  late Animation<double> _line1Anim;
  late Animation<double> _line2Anim;
  late Animation<double> _line3Anim;
  late Animation<double> _docAnim;
  late Animation<double> _textAnim;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000), // Slower animation
      vsync: this,
    );

    // Top node: 0s - 0.6s
    _topNodeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.1875, curve: Curves.easeOut),
      ),
    );
    
    // Left node: 0.3s - 0.9s
    _leftNodeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.09375, 0.28125, curve: Curves.easeOut),
      ),
    );
    
    // Right node: 0.6s - 1.2s
    _rightNodeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1875, 0.375, curve: Curves.easeOut),
      ),
    );

    // Line 1: 0.9s - 1.7s
    _line1Anim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28125, 0.53125, curve: Curves.easeOut),
      ),
    );
    
    // Line 2: 1.2s - 2.0s
    _line2Anim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.375, 0.625, curve: Curves.easeOut),
      ),
    );
    
    // Line 3: 1.5s - 2.3s
    _line3Anim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.46875, 0.71875, curve: Curves.easeOut),
      ),
    );

    // Document: 1.8s - 2.4s
    _docAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5625, 0.75, curve: Curves.easeOut),
      ),
    );

    // Text: 2.4s - 3.2s
    _textAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Navigate based on terms acceptance after animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          _navigateBasedOnTermsAcceptance();
        }
      }
    });
    
    // Fallback navigation after 5 seconds in case animation fails
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _navigateBasedOnTermsAcceptance();
      }
    });
  }

  void _navigateBasedOnTermsAcceptance() {
    final settings = Provider.of<AppSettings>(context, listen: false);
    
    if (settings.termsAccepted) {
      // Terms already accepted, check if user name is set
      if (settings.userName.isEmpty) {
        // User name not set, go to welcome screen
        context.go('/welcome');
      } else {
        // User name set, go to home screen
        context.go('/');
      }
    } else {
      // Terms not yet accepted, go to terms screen
      context.go('/terms');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive scaling for tablets
    final scale = ResponsiveUtils.getContentScale(context);
    final iconSize = 200 * scale;
    final titleSize = 36 * scale;
    final subtitleSize = 16 * scale;
    final loaderSize = 24 * scale;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE63946), // Primary red (from app icon)
              Color(0xFFD32F2F), // Medium red
              Color(0xFFB71C1C), // Dark red
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Radial gradient overlay for depth
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.5),
                  radius: 1.5,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE63946), Color(0xFFB71C1C)],
                          ),
                          borderRadius: BorderRadius.circular(40 * scale),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 40 * scale,
                              offset: Offset(0, 15 * scale),
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: PDFHubPainter(
                            topNodeOpacity: _topNodeAnim.value,
                            leftNodeOpacity: _leftNodeAnim.value,
                            rightNodeOpacity: _rightNodeAnim.value,
                            line1Progress: _line1Anim.value,
                            line2Progress: _line2Anim.value,
                            line3Progress: _line3Anim.value,
                            documentScale: _docAnim.value,
                            textOpacity: _textAnim.value,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 32 * scale),
                  // App name with enhanced styling
                  Text(
                    'PDF Hub',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: const [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  // Tagline
                  Text(
                    'Professional PDF Processing',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: subtitleSize,
                      color: const Color(0xFFFFCDD2),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 48 * scale),
                  // Loading indicator with enhanced styling
                  SizedBox(
                    width: loaderSize,
                    height: loaderSize,
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PDFHubPainter extends CustomPainter {
  final double topNodeOpacity;
  final double leftNodeOpacity;
  final double rightNodeOpacity;
  final double line1Progress;
  final double line2Progress;
  final double line3Progress;
  final double documentScale;
  final double textOpacity; // Keep for compatibility but don't use

  PDFHubPainter({
    required this.topNodeOpacity,
    required this.leftNodeOpacity,
    required this.rightNodeOpacity,
    required this.line1Progress,
    required this.line2Progress,
    required this.line3Progress,
    required this.documentScale,
    required this.textOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 400;
    
    // Node positions (matching HTML: 140, 40 / 50, 180 / 230, 180 in 280px viewBox)
    // Scaled to 400px container
    final topNode = Offset(200 * scale, 57.14 * scale);
    final leftNode = Offset(71.43 * scale, 257.14 * scale);
    final rightNode = Offset(328.57 * scale, 257.14 * scale);

    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2 * scale
      ..style = PaintingStyle.stroke;

    // Draw triangle lines with progress
    if (line1Progress > 0) {
      final end = Offset.lerp(topNode, leftNode, line1Progress)!;
      canvas.drawLine(topNode, end, linePaint);
    }

    if (line2Progress > 0) {
      final end = Offset.lerp(topNode, rightNode, line2Progress)!;
      canvas.drawLine(topNode, end, linePaint);
    }

    if (line3Progress > 0) {
      final end = Offset.lerp(leftNode, rightNode, line3Progress)!;
      canvas.drawLine(leftNode, end, linePaint);
    }

    // Draw nodes
    if (topNodeOpacity > 0) {
      nodePaint.color = Colors.white.withOpacity(topNodeOpacity);
      canvas.drawCircle(topNode, 21.43 * scale, nodePaint);
    }
    if (leftNodeOpacity > 0) {
      nodePaint.color = Colors.white.withOpacity(leftNodeOpacity);
      canvas.drawCircle(leftNode, 21.43 * scale, nodePaint);
    }
    if (rightNodeOpacity > 0) {
      nodePaint.color = Colors.white.withOpacity(rightNodeOpacity);
      canvas.drawCircle(rightNode, 21.43 * scale, nodePaint);
    }

    // Draw document
    if (documentScale > 0) {
      canvas.save();
      
      // Document center position (matching HTML)
      final docCenterX = 200 * scale;
      final docCenterY = 207.14 * scale;
      
      canvas.translate(docCenterX, docCenterY);
      canvas.scale(documentScale);
      canvas.translate(-docCenterX, -docCenterY);

      // Document rectangle (85, 75, width: 110, height: 140 in HTML)
      final docRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          121.43 * scale,
          107.14 * scale,
          157.14 * scale,
          200 * scale,
        ),
        Radius.circular(5.71 * scale),
      );
      
      final docPaint = Paint()..color = Colors.white;
      canvas.drawRRect(docRect, docPaint);

      // Folded corner
      final cornerPath = Path()
        ..moveTo(264.29 * scale, 107.14 * scale)
        ..lineTo(264.29 * scale, 135.71 * scale)
        ..lineTo(278.57 * scale, 135.71 * scale)
        ..close();
      
      canvas.drawPath(cornerPath, Paint()..color = const Color(0xFFe0e0e0));
      canvas.drawPath(
        cornerPath,
        Paint()
          ..color = const Color(0xFFd0d0d0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );

      // Document lines
      final lineDocPaint = Paint()
        ..color = const Color(0xFF2a2a2a)
        ..strokeWidth = 4.29 * scale
        ..strokeCap = StrokeCap.round;

      final lines = [
        (157.14, 242.86),
        (185.71, 242.86),
        (214.29, 242.86),
        (242.86, 242.86),
        (271.43, 207.14),
      ];
      
      for (var line in lines) {
        canvas.drawLine(
          Offset(142.86 * scale, line.$1 * scale),
          Offset(line.$2 * scale, line.$1 * scale),
          lineDocPaint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PDFHubPainter oldDelegate) => true;
}