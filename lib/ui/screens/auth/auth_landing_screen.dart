import 'package:flutter/material.dart';

/// Landing chooser between owner email login and staff PIN login.
class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({
    super.key,
    required this.onOwnerLogin,
    required this.onStaffLogin,
    this.onLegal,
  });

  final VoidCallback onOwnerLogin;
  final VoidCallback onStaffLogin;
  final VoidCallback? onLegal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome to Smart Bar Stock',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to log in.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _ActionButton(
                  icon: Icons.business_center,
                  title: 'Login as Business Owner',
                  subtitle: 'Email + password, manage companies and staff',
                  onPressed: onOwnerLogin,
                ),
                const SizedBox(height: 16),
                _ActionButton(
                  icon: Icons.badge,
                  title: 'Login as Staff (Business ID + PIN)',
                  subtitle: 'Use company code and staff PIN to start shifts',
                  onPressed: onStaffLogin,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onLegal,
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Privacy & Terms'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        minimumSize: const Size.fromHeight(86),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
