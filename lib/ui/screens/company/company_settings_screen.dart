import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/company_repository.dart';
import '../../../models/company.dart';
import '../../../models/company_member.dart';

class CompanySettingsScreen extends StatelessWidget {
  final String companyId;
  final CompanyRepository repository;
  final bool canRegenerate;

  const CompanySettingsScreen({
    super.key,
    required this.companyId,
    required this.repository,
    this.canRegenerate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company settings'),
      ),
      body: StreamBuilder<Company>(
        stream: repository.watchCompany(companyId),
        builder: (context, companySnap) {
          final company = companySnap.data;
          final businessIdController = TextEditingController(
            text: company?.businessId ?? '',
          );
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company join code',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (company == null)
                          const Text('Loading...')
                        else
                          Row(
                            children: [
                              SelectableText(
                                company.joinCode,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy code',
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: company.joinCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Join code copied'),
                                    ),
                                  );
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: canRegenerate
                                    ? 'Regenerate code'
                                    : 'Only owners can regenerate',
                                onPressed: canRegenerate
                                    ? () => _confirmRegenerate(context)
                                    : null,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'Share this code with staff who need to join the company.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business ID (for staff login)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (company == null)
                          const Text('Loading...')
                        else ...[
                          TextField(
                            controller: businessIdController,
                            maxLength: 8,
                            textCapitalization:
                                TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Business ID (4-8 letters/numbers)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: canRegenerate
                                    ? () => _saveBusinessId(
                                          context,
                                          businessIdController.text,
                                        )
                                    : null,
                                icon: const Icon(Icons.save),
                                label: const Text('Save'),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Copy Business ID',
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: businessIdController.text,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Business ID copied'),
                                    ),
                                  );
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: canRegenerate
                                    ? 'Generate random'
                                    : 'Only owners can regenerate',
                                onPressed: canRegenerate
                                    ? () => _confirmRegenerateBusinessId(context)
                                    : null,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Share this Business ID with staff to pair with their PIN.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Members',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<CompanyMember>>(
                    stream: repository.watchMembers(companyId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final members = snapshot.data!;
                      if (members.isEmpty) {
                        return const Center(
                          child: Text('No members yet'),
                        );
                      }
                      return ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(member.displayName),
                            subtitle: Text(member.role.toUpperCase()),
                            trailing:
                                member.disabled ? const Text('DISABLED') : null,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRegenerate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate join code'),
        content: const Text(
          'Regenerating the code will invalidate the old code. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final newCode = await repository.regenerateJoinCode(companyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Join code updated: $newCode')),
        );
      }
    }
  }

  Future<void> _confirmRegenerateBusinessId(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Business ID'),
        content: const Text(
          'Regenerating will replace the current Business ID. Staff will need the new value to log in. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final newCode = await repository.regenerateBusinessId(companyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Business ID updated: $newCode')),
        );
      }
    }
  }

  Future<void> _saveBusinessId(
    BuildContext context,
    String value,
  ) async {
    try {
      final updated =
          await repository.updateBusinessId(companyId, value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Business ID set to $updated')),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err is ArgumentError || err is StateError
                  ? err.toString()
                  : 'Failed to update Business ID',
            ),
          ),
        );
      }
    }
  }
}
