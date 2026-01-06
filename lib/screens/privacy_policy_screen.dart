import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFF2E3A59),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2D2D44), const Color(0xFF1A1A2E)]
                        : [const Color(0xFF3D4F7C), const Color(0xFF2E3A59)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4A80F0).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80F0).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.privacy_tip_rounded,
                        color: Color(0xFF4A80F0),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Last updated: December 17, 2024',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFFA0B4D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Introduction
              _buildIntro(isDark),
              
              // Privacy content sections
              _buildSection(
                '1. Information Collection and Use',
                '',
                isDark,
              ),
              
              _buildSubSection(
                '1.1 Personal Information',
                'We do not collect contact information such as your email address, phone number, or physical address.\n\n'
                'User Name / Nickname: Upon launching the App, we may ask you to input a name or nickname. '
                'This is used solely to personalize the App interface (e.g., for greetings). '
                'This information is stored locally on your device within the Application\'s preferences. '
                'It is not transmitted to our servers and is permanently deleted if you uninstall the Application or clear the App data.',
                isDark,
              ),
              
              _buildSubSection(
                '1.2 Files and Documents',
                '• Your PDF files, images, and documents are processed locally on your device.\n'
                '• When you edit, convert, merge, or split PDFs, the operations are performed using your device\'s processor.\n'
                '• Your files are never uploaded to our servers or any third-party cloud storage by the App.',
                isDark,
              ),
              
              _buildSubSection(
                '1.3 Device Permissions',
                'To function correctly, the App requires specific permissions:\n\n'
                '• Camera: Used strictly for the "Scanner" and "Image to PDF" features to capture documents. These images are stored locally on your device.\n\n'
                '• Storage / File Access: We use the system file picker (Storage Access Framework) to allow you to select and save files. We do not have broad access to your entire file system.',
                isDark,
              ),
              
              _buildSection(
                '2. Third-Party Services',
                'While the App itself does not collect personal data, we use third-party services to support the application '
                '(e.g., to display advertisements and facilitate in-app purchases). These services may collect information '
                'used to identify your device, such as your Advertising ID.\n\n'
                'Third-party service providers used by the App:\n\n'
                '• Google Play Services\n'
                '• AdMob (Google)\n'
                '• Google Analytics for Firebase\n\n'
                'Advertising: We use Google AdMob to display ads. AdMob may use your device\'s Advertising ID to show personalized ads. '
                'You can opt-out of personalized advertising in your Android device settings (Settings > Google > Ads).',
                isDark,
              ),
              
              _buildSection(
                '3. Data Safety & Security',
                '• Local Processing: All core PDF operations (OCR, conversion, compression) are performed offline.\n\n'
                '• Encryption: Any communication with third-party services (like Google Play Store for payments or AdMob for ads) '
                'is encrypted in transit using SSL/TLS protocols.',
                isDark,
              ),
              
              _buildSection(
                '4. Children\'s Privacy',
                'These Services do not address anyone under the age of 13. We do not knowingly collect personally identifiable information from children under 13.',
                isDark,
              ),
              
              _buildSection(
                '5. GDPR Compliance (European Users)',
                'If you are located in the European Economic Area (EEA), you have certain data protection rights. '
                'Since we use Google AdMob, we comply with the IAB Europe Transparency & Consent Framework.\n\n'
                '• Upon first launch, you may be presented with a consent form regarding personalized advertisements.\n'
                '• You have the right to withdraw consent at any time within the app settings or your device settings.',
                isDark,
              ),
              
              _buildSection(
                '6. CCPA/CPRA Compliance (US Users)',
                'Under the California Consumer Privacy Act (CCPA), California residents have the right to opt-out of the "sale" of their personal information.\n\n'
                '• We do not sell your personal data.\n'
                '• We do not collect personal data to sell.\n'
                '• AdMob usage complies with CCPA restricted data processing guidelines.',
                isDark,
              ),
              
              _buildSection(
                '7. Changes to This Privacy Policy',
                'We may update our Privacy Policy from time to time. Thus, you are advised to review this page periodically for any changes. '
                'These changes are effective immediately after they are posted on this page.',
                isDark,
              ),
              
              _buildSection(
                '8. Contact Us',
                'If you have any questions or suggestions about our Privacy Policy, do not hesitate to contact us at:\n\n'
                'Email: pdfhub09@gmail.com',
                isDark,
              ),
              
              const SizedBox(height: 32),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: Colors.green.shade400,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'PDF Hub respects your privacy. Your files are processed locally and never leave your device.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFFA0B4D9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildIntro(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'This Privacy Policy describes how PDF Hub - Edit & Convert PDF ("we," "us," or "our") collects, uses, and discloses your information.\n\n'
        'We respect your privacy. PDF Hub is designed to process your files locally on your device. We do not upload your documents to any server for processing.',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: Color(0xFFCCD6E8),
          height: 1.6,
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, String content, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                content,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFFCCD6E8),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSubSection(String title, String content, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCCD6E8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.03)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF4A80F0).withOpacity(0.1),
              ),
            ),
            child: Text(
              content,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFFB0C4DE),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
