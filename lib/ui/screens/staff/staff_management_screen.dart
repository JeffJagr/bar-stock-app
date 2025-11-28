import 'package:flutter/material.dart';

import '../../../data/staff_repository.dart';
import '../../../models/company_member.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({
    super.key,
    required this.companyId,
    this.repository,
    this.businessId,
  });

  final String companyId;
  final StaffRepository? repository;
  final String? businessId;

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late final StaffRepository _repository;
  late Future<List<CompanyMember>> _loadFuture;
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String _role = 'staff';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StaffRepository();
    _loadFuture = _repository.listMembers(widget.companyId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _repository.listMembers(widget.companyId);
    });
  }

  Future<void> _createMember() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (name.isEmpty || pin.length < 4) {
      setState(() => _error = 'Name and a 4+ digit PIN are required');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.createOrUpdateMember(
        companyId: widget.companyId,
        displayName: name,
        role: _role,
        pin: pin,
      );
      _nameController.clear();
      _pinController.clear();
      _confirmController.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created $_role $name')),
        );
      }
    } catch (_) {
      setState(() => _error = 'Failed to create staff member');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resetPin(CompanyMember member) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset PIN for ${member.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New PIN',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (pin.length < 4) {
                error = 'PIN must be at least 4 digits';
              } else if (pin != confirm) {
                error = 'PINs do not match';
              } else {
                Navigator.of(ctx).pop(true);
              }
              (ctx as Element).markNeedsBuild();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.createOrUpdateMember(
      companyId: widget.companyId,
      memberId: member.memberId,
      displayName: member.displayName,
      role: member.role,
      pin: pinController.text.trim(),
      disabled: member.disabled,
    );
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated')),
      );
    }
  }

  Future<void> _toggleDisable(CompanyMember member, bool disabled) async {
    await _repository.createOrUpdateMember(
      companyId: widget.companyId,
      memberId: member.memberId,
      displayName: member.displayName,
      role: member.role,
      disabled: disabled,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff management'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.businessId != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.badge),
                      const SizedBox(width: 8),
                      const Text('Business ID:'),
                      const SizedBox(width: 8),
                      SelectableText(
                        widget.businessId!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _buildCreateCard(),
            const SizedBox(height: 16),
            FutureBuilder<List<CompanyMember>>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = snapshot.data ?? [];
                if (members.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No staff yet'),
                    ),
                  );
                }
                return Card(
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (context, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return ListTile(
                        title: Text(member.displayName),
                        subtitle: Text(member.role.toUpperCase()),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Reset PIN',
                              icon: const Icon(Icons.key),
                              onPressed: () => _resetPin(member),
                            ),
                            Switch(
                              value: !member.disabled,
                              onChanged: (value) =>
                                  _toggleDisable(member, !value),
                              activeThumbColor:
                                  Theme.of(context).colorScheme.primary,
                              inactiveThumbColor: Colors.red,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add staff member',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: const [
                DropdownMenuItem(
                  value: 'manager',
                  child: Text('Manager'),
                ),
                DropdownMenuItem(
                  value: 'staff',
                  child: Text('Staff'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _role = value);
              },
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN (4+ digits)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _createMember,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: Text(_busy ? 'Saving...' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
