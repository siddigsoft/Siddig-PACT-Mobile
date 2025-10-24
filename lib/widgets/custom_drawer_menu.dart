import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class CustomDrawerMenu extends StatelessWidget {
  final User? currentUser;
  final VoidCallback onClose;

  const CustomDrawerMenu({
    Key? key,
    required this.currentUser,
    required this.onClose,
  }) : super(key: key);

  Future<void> _launchPactWebsite(BuildContext context) async {
    final url = Uri.parse('https://pactorg1.com/about/');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try without checking
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Show error message to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open website. Please check your internet connection.'),
          ),
        );
      }
    }
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'francis.b.kaz@gmail.com',
      queryParameters: {
        'subject': 'PACT Mobile App Feedback',
        'body': 'Dear Developer,\n\nI would like to provide feedback about the PACT Mobile app:\n\n'
      },
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        // Fallback: try without checking
        await launchUrl(emailLaunchUri);
      }
    } catch (e) {
      // Show error message to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open email app. Please check if you have an email app installed.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            accountName: Text(
              currentUser?.userMetadata?['full_name'] ?? 'User',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(
              currentUser?.email ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (currentUser?.userMetadata?['full_name'] as String?)?.isNotEmpty == true
                    ? (currentUser!.userMetadata!['full_name'] as String)[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 32.0,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About PACT'),
            onTap: () async {
              await _launchPactWebsite(context);
              onClose();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () async {
              await _sendFeedback(context);
              onClose();
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Sign Out'),
            onTap: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}