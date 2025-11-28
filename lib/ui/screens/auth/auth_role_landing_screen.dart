import 'package:flutter/material.dart';

import '../../../models/cloud_user_role.dart';

class AuthRoleLandingScreen extends StatelessWidget {
  final void Function(CloudUserRole role) onRoleSelected;

  const AuthRoleLandingScreen({super.key, required this.onRoleSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                const SizedBox(height: 12),
                Text(
                  'Choose how you want to log in',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _RoleButton(
                  icon: Icons.business_center,
                  title: 'Login as Business Owner',
                  subtitle: 'Email + password, manage companies and staff',
                  onPressed: () => onRoleSelected(CloudUserRole.owner),
                ),
                const SizedBox(height: 16),
                _RoleButton(
                  icon: Icons.badge,
                  title: 'Login as Staff (Worker/Manager)',
                  subtitle: 'Use Business ID + PIN',
                  onPressed: () => onRoleSelected(CloudUserRole.worker),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  const _RoleButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        minimumSize: const Size.fromHeight(90),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
