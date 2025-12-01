import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched) {
        throw const FormatException('Could not launch URL');
      }
    } catch (_) {
      final fallback = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!fallback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Terms'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legal',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Review the legal policies for Smart Bar Stock. These open in your browser or an in-app view.',
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    subtitle: Text(AppConfig.privacyPolicyUrl),
                    onTap: () => _openLink(context, AppConfig.privacyPolicyUrl),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Use'),
                    subtitle: Text(AppConfig.termsOfUseUrl),
                    onTap: () => _openLink(context, AppConfig.termsOfUseUrl),
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
