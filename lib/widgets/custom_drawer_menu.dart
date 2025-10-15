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

  Future<void> _launchPactWebsite() async {
    final url = Uri.parse('https://pactorg1.com/about/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendFeedback() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'francis.b.kaz@gmail.com',
      queryParameters: {
        'subject': 'PACT Mobile App Feedback',
        'body': 'Dear Developer,\n\nI would like to provide feedback about the PACT Mobile app:\n\n'
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
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
            onTap: () {
              _launchPactWebsite();
              onClose();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {
              _sendFeedback();
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