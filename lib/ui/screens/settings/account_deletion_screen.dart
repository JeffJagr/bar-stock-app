import 'package:flutter/material.dart';

import '../../../core/account_deletion_controller.dart';
import '../../../models/company.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    super.key,
    required this.company,
    required this.userId,
    required this.onDeleted,
  });

  final Company company;
  final String userId;
  final Future<void> Function() onDeleted;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _controller = AccountDeletionController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isConfirmed =>
      _confirmController.text.trim().toLowerCase() ==
      (widget.company.name.trim().toLowerCase());

  Future<void> _delete() async {
    if (!_isConfirmed || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _controller.deleteOwnerAndCompany(
        userId: widget.userId,
        companyId: widget.company.companyId,
      );
      if (mounted) {
        await widget.onDeleted();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion failed: $err')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete my account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'This is permanent',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Deleting your owner account will remove your company data (products, inventory, orders, history, staff, and memberships). This action cannot be undone.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm company',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Type the company name to confirm you want to delete "${widget.company.name}" and your account. You will be signed out immediately.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmController,
                    decoration: InputDecoration(
                      labelText: 'Type "${widget.company.name}" to confirm',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor:
                          Theme.of(context).colorScheme.onErrorContainer,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _isConfirmed && !_submitting ? _delete : null,
                    icon: const Icon(Icons.delete_forever),
                    label: Text(_submitting
                        ? 'Deleting...'
                        : 'Delete account and company'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We delete: company document, members, staff, groups, products, inventory, orders, and history. User profile is removed and we attempt to delete your auth account.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
