import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4F46E5),
              Color(0xFF6366F1),
              Color(0xFF818CF8),
              Color(0xFF3B82F6),
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _buildSection(
                icon: Icons.storage_outlined,
                title: 'Data We Collect',
                items: const [
                  'Name and email address (for account creation)',
                  'Meter readings and utility usage history',
                  'Photos of utility meters (for AI recognition)',
                ],
              ),
              _buildSection(
                icon: Icons.auto_awesome,
                title: 'AI-Powered Recognition',
                items: const [
                  'When you scan a meter, the photo is sent to OpenAI for digit recognition.',
                  'Only the meter photo and utility type are sent — no personal information (no name, email, or user ID).',
                  'Photos are not used to train AI models.',
                  'Processing happens in real time and photos are not stored by OpenAI.',
                ],
              ),
              _buildSection(
                icon: Icons.info_outline,
                title: 'How We Use Your Data',
                items: const [
                  'Authentication and account management',
                  'Storing your meter reading history',
                  'Calculating utility bills based on your tariffs',
                  'We do not sell or share your data for advertising.',
                ],
              ),
              _buildSection(
                icon: Icons.shield_outlined,
                title: 'Data Security',
                items: const [
                  'JWT-based authentication with bcrypt password hashing',
                  'All data transmitted over HTTPS',
                  'Tokens stored in encrypted device storage',
                  'Rate limiting to prevent abuse',
                ],
              ),
              _buildSection(
                icon: Icons.delete_outline,
                title: 'Account Deletion',
                items: const [
                  'You can delete your account at any time from the app menu.',
                  'Deletion is permanent and removes all your data including meters, readings, and bills.',
                ],
              ),
              _buildSection(
                icon: Icons.handshake_outlined,
                title: 'Third-Party Services',
                items: const [
                  'OpenAI — meter photo recognition (photos only, no PII)',
                  'Google Sign-In — optional OAuth authentication',
                  'Apple Sign-In — optional OAuth authentication (iOS)',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
