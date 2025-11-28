import 'package:flutter/material.dart';

class JoinCompanyPlaceholder extends StatelessWidget {
  final VoidCallback? onRefresh;
  final VoidCallback? onSignOut;
  final VoidCallback? onEnterCode;

  const JoinCompanyPlaceholder({
    super.key,
    this.onRefresh,
    this.onSignOut,
    this.onEnterCode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_add, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 16),
            const Text(
              'Waiting for an invitation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask a business owner for their company code or wait for an invitation. '
              'You will see the company once you join.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onEnterCode != null)
              FilledButton.icon(
                onPressed: onEnterCode,
                icon: const Icon(Icons.key),
                label: const Text('Have a company code?'),
              ),
            if (onRefresh != null)
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Check again'),
              ),
            if (onSignOut != null)
              TextButton(
                onPressed: onSignOut,
                child: const Text('Sign out'),
              ),
          ],
        ),
      ),
    );
  }
}
