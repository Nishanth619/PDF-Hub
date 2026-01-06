import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';

class TermsScreen extends StatefulWidget {
  /// When true, shows Accept/Decline buttons (for first launch after splash).
  /// When false, shows only terms content with back navigation (for settings).
  final bool showButtons;
  
  const TermsScreen({super.key, this.showButtons = true});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = widget.showButtons 
        ? const Color(0xFF2E3A59) 
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final headerColor = widget.showButtons 
        ? const Color(0xFF2E3A59) 
        : (isDark ? const Color(0xFF2E3A59) : const Color(0xFF2E3A59));
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: widget.showButtons ? null : AppBar(
        title: const Text('Terms & Conditions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header section - only show custom header when showButtons is true
            if (widget.showButtons)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: headerColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Terms of Service',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Last Updated: December 18, 2024',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Color(0xFFA0B4D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('1. Acceptance of Terms'),
                    _buildSectionContent(
                      'By downloading, installing, or using PDF Hub - Edit & Convert PDF ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('2. License Grant'),
                    _buildSectionContent(
                      'We grant you a limited, non-exclusive, non-transferable license to use the App for personal or business purposes in accordance with these Terms.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('3. Permitted Uses'),
                    _buildSubSection('Personal Use'),
                    _buildBulletList([
                      'Process your own PDF documents.',
                      'Convert files between supported formats.',
                      'Edit and modify your documents.',
                      'Share processed files as permitted by law.',
                    ]),
                    const SizedBox(height: 8),
                    _buildSubSection('Business Use'),
                    _buildBulletList([
                      'Use the App for legitimate business purposes.',
                      'Process company documents with proper authorization.',
                      'Comply with your organization\'s policies.',
                    ]),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('4. Prohibited Activities'),
                    _buildSubSection('Illegal Activities'),
                    _buildBulletList([
                      'Process illegal or copyrighted content without permission.',
                      'Use the App for fraudulent purposes.',
                      'Violate any applicable laws or regulations.',
                    ]),
                    const SizedBox(height: 8),
                    _buildSubSection('Technical Misuse'),
                    _buildBulletList([
                      'Reverse engineer, decompile, or attempt to derive the source code.',
                      'Modify or create derivative works.',
                      'Interfere with the App\'s operation or security features.',
                    ]),
                    const SizedBox(height: 8),
                    _buildSubSection('Abuse'),
                    _buildBulletList([
                      'Excessive use that impacts device performance.',
                      'Automated processing without permission.',
                      'Reselling or redistributing the App binary.',
                    ]),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('5. Intellectual Property'),
                    _buildSubSection('Our Rights'),
                    _buildBulletList([
                      'All intellectual property in the App (code, design, logos) belongs to us.',
                      'The App is protected by copyright, trademark, and other laws.',
                      'You receive only a license to use the App, not ownership of the App itself.',
                    ]),
                    const SizedBox(height: 8),
                    _buildSubSection('Your Rights & Content'),
                    _buildSectionContent(
                      'You retain full ownership of the documents and files you process using the App.\n\n'
                      'Local Processing: We do not claim ownership of your files. Since the App processes files locally on your device, we do not access, view, or store your content on our servers.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('6. Disclaimer of Warranties'),
                    _buildSectionContent(
                      'THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. WE DO NOT WARRANT THAT THE APP WILL BE ERROR-FREE OR UNINTERRUPTED.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('7. Limitation of Liability'),
                    _buildSectionContent(
                      'TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THESE TERMS OR THE USE OF THE APP, INCLUDING LOSS OF DATA.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('8. Indemnification'),
                    _buildSectionContent(
                      'You agree to indemnify and hold us harmless from any claims, damages, or expenses arising from your use of the App or violation of these Terms.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('9. Termination'),
                    _buildSectionContent(
                      'We may terminate or suspend your access to the App at any time for any reason, including violation of these Terms.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('10. Changes to Terms'),
                    _buildSectionContent(
                      'We may modify these Terms at any time. We will notify you of significant changes by updating the "Last Updated" date at the top of this document.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('11. Governing Law'),
                    _buildSectionContent(
                      'These Terms are governed by the laws of your jurisdiction without regard to conflict of law principles.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('12. Severability'),
                    _buildSectionContent(
                      'If any provision of these Terms is held invalid, the remainder will continue in full force and effect.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('13. Entire Agreement'),
                    _buildSectionContent(
                      'These Terms constitute the entire agreement between you and us regarding the App\'s use.'
                    ),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('14. Contact Information'),
                    _buildSectionContent(
                      'For questions about these Terms, please contact:\n\nEmail: pdfhub09@gmail.com'
                    ),
                    
                    const SizedBox(height: 24),
                    // Only show checkbox during first launch
                    if (widget.showButtons)
                      Row(
                        children: [
                          Checkbox(
                            value: _accepted,
                            onChanged: (value) {
                              setState(() {
                                _accepted = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF4A80F0),
                            checkColor: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'I accept the Terms of Service',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
            // Action buttons - only show during first launch
            if (widget.showButtons)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3A59),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Decline button (LEFT)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _declineTerms,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept button (RIGHT)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _accepted ? _acceptTerms : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43A047),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.showButtons 
        ? Colors.white 
        : (isDark ? Colors.white : const Color(0xFF2E3A59));
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSubSection(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.showButtons 
        ? const Color(0xFFCCD6E8) 
        : (isDark ? const Color(0xFFCCD6E8) : const Color(0xFF5A6A7A));
    
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.showButtons 
        ? Colors.white.withOpacity(0.05) 
        : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100);
    final textColor = widget.showButtons 
        ? const Color(0xFFC0D0E9) 
        : (isDark ? const Color(0xFFC0D0E9) : const Color(0xFF5A6A7A));
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        content,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: textColor,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBulletList(List<String> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.showButtons 
        ? Colors.white.withOpacity(0.03) 
        : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50);
    final textColor = widget.showButtons 
        ? const Color(0xFFB0C4DE) 
        : (isDark ? const Color(0xFFB0C4DE) : const Color(0xFF6A7A8A));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  color: Color(0xFF4A80F0),
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  void _acceptTerms() {
    // Save terms acceptance status
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.termsAccepted = true;
    
    // Check if user name is set
    if (settings.userName.isEmpty) {
      // User name not set, go to welcome screen
      context.go('/welcome');
    } else {
      // User name set, go to home screen
      context.go('/');
    }
  }

  void _declineTerms() {
    // Show confirmation dialog before closing app
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Decline Terms'),
          content: const Text(
            'You must accept the Terms of Service to use this application. '
            'The app will close if you decline. Are you sure you want to decline?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _closeApp,
              child: const Text(
                'Decline & Close',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _closeApp() {
    // Close the application
    if (Platform.isAndroid) {
      // For Android, we can use SystemNavigator.pop()
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      // For iOS, we show a message since we can't directly close the app
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please close the app from the app switcher'),
          duration: Duration(seconds: 3),
        ),
      );
      // Give user time to see the message before attempting to close
      Future.delayed(const Duration(seconds: 3), () {
        SystemNavigator.pop();
      });
    } else {
      // For other platforms, attempt to close
      SystemNavigator.pop();
    }
  }
}