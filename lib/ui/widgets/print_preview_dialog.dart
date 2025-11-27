import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/print_service.dart';

class PrintPreviewDialog {
  static Future<void> show(
    BuildContext context,
    AppState state,
    PrintSection section,
  ) async {
    final service = const PrintService();
    final text = service.buildSection(state, section);
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nothing to export for '
              '${PrintService.sectionLabel(section)}'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Export - ${PrintService.sectionLabel(section)}'),
          content: SizedBox(
            width: 480,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: text),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied export text')),
                );
              },
              child: const Text('Copy text'),
            ),
            if (_supportsNativePrint)
              TextButton(
                onPressed: () {
                  _simulateNativePrint(context, text, section);
                },
                child: const Text('System print'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static bool get _supportsNativePrint {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  static void _simulateNativePrint(
    BuildContext context,
    String text,
    PrintSection section,
  ) {
    Navigator.of(context).pop();
    final label = _platformLabel(defaultTargetPlatform);
    debugPrint(
      'Printing ($label) [${PrintService.sectionLabel(section)}]:\n$text',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sent ${PrintService.sectionLabel(section)} to the $label print dialog.',
        ),
      ),
    );
  }

  static String _platformLabel(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
