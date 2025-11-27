import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_notifier.dart';
import '../../../core/app_state.dart';
import '../../../core/models/staff_member.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _loginController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  StaffRole _selectedRole = StaffRole.worker;
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final state = notifier.state;
    final staff = state.staff.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final current = _resolveCurrentStaff(state);
    final creationRoles = _creationRoles(current);
    StaffRole? roleValue;
    if (creationRoles.isNotEmpty) {
      roleValue = creationRoles.contains(_selectedRole)
          ? _selectedRole
          : creationRoles.first;
      if (_selectedRole != roleValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || roleValue == null) return;
          setState(() => _selectedRole = roleValue!);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Staff management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCreateCard(
              notifier: notifier,
              current: current,
              creationRoles: creationRoles,
              roleValue: roleValue,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: staff.isEmpty
                  ? const Center(child: Text('No staff yet'))
                  : _buildStaffList(notifier, current, staff),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard({
    required AppNotifier notifier,
    required StaffMember? current,
    required List<StaffRole> creationRoles,
    required StaffRole? roleValue,
  }) {
    final canCreate = current != null && creationRoles.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create account',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _loginController,
              enabled: canCreate,
              decoration: const InputDecoration(
                labelText: 'Login',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: canCreate,
              decoration: const InputDecoration(
                labelText: 'Display name',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<StaffRole>(
              initialValue: roleValue,
              items: creationRoles
                  .map(
                    (r) =>
                        DropdownMenuItem(value: r, child: Text(_roleLabel(r))),
                  )
                  .toList(),
              onChanged: canCreate
                  ? (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    }
                  : null,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              enabled: canCreate,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: canCreate
                    ? () => _submit(notifier, roleValue)
                    : null,
                icon: const Icon(Icons.person_add),
                label: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList(
    AppNotifier notifier,
    StaffMember? current,
    List<StaffMember> staff,
  ) {
    return ListView.builder(
      itemCount: staff.length,
      itemBuilder: (context, index) {
        final member = staff[index];
        final canEdit = _canEditMember(current, member);
        final canDelete = _canDeleteMember(current, member);
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
            ),
          ),
          title: Text(member.displayName),
          subtitle: Text('${member.login} • ${_roleLabel(member.role)}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit account',
                icon: const Icon(Icons.edit),
                onPressed: canEdit
                    ? () => _showEditDialog(notifier, member, current)
                    : null,
              ),
              IconButton(
                tooltip: 'Delete account',
                icon: const Icon(Icons.delete),
                onPressed: canDelete
                    ? () => _confirmDelete(notifier, member)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit(AppNotifier notifier, StaffRole? roleValue) {
    final roleToCreate = roleValue;
    final login = _loginController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    if (roleToCreate == null) {
      setState(() {
        _error = 'You do not have permission to create accounts.';
      });
      return;
    }
    if (login.isEmpty || name.isEmpty || password.length < 4) {
      setState(() {
        _error = 'Login, name and password (min 4 chars) are required.';
      });
      return;
    }
    final error = notifier.createStaffAccount(
      login,
      name,
      roleToCreate,
      password,
    );
    if (error != null) {
      setState(() => _error = error);
    } else {
      setState(() {
        _error = null;
        _loginController.clear();
        _nameController.clear();
        _passwordController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Staff account created')));
    }
  }

  StaffMember? _resolveCurrentStaff(AppState state) {
    final activeId = state.activeStaffId;
    if (activeId == null) return null;
    for (final staff in state.staff) {
      if (staff.id == activeId) return staff;
    }
    return null;
  }

  List<StaffRole> _creationRoles(StaffMember? current) {
    if (current == null) return const [];
    switch (current.role) {
      case StaffRole.admin:
        return StaffRole.values.toList();
      case StaffRole.owner:
        return const [StaffRole.manager, StaffRole.worker];
      case StaffRole.manager:
        return const [StaffRole.worker];
      case StaffRole.worker:
        return const [];
    }
  }

  List<StaffRole> _editRoles(StaffMember? current, StaffMember target) {
    if (current == null) return const [];
    final roles = <StaffRole>{..._creationRoles(current)};
    roles.add(target.role);
    if (current.role == StaffRole.admin) {
      roles.addAll(StaffRole.values);
    }
    if (current.id == target.id) {
      roles.add(target.role);
    }
    if (current.role == StaffRole.owner && current.id == target.id) {
      roles.add(StaffRole.owner);
    }
    if (current.role == StaffRole.manager && current.id == target.id) {
      roles.add(StaffRole.manager);
    }
    return roles.toList();
  }

  bool _canEditMember(StaffMember? current, StaffMember target) {
    if (current == null) return false;
    if (current.id == target.id) return true;
    switch (current.role) {
      case StaffRole.admin:
        return true;
      case StaffRole.owner:
        if (target.role == StaffRole.admin) return false;
        if (target.role == StaffRole.owner) return false;
        return true;
      case StaffRole.manager:
        return target.role == StaffRole.worker;
      case StaffRole.worker:
        return false;
    }
  }

  bool _canDeleteMember(StaffMember? current, StaffMember target) {
    if (current == null) return false;
    if (current.id == target.id) return false;
    return _canEditMember(current, target);
  }

  Future<void> _showEditDialog(
    AppNotifier notifier,
    StaffMember member,
    StaffMember? current,
  ) async {
    final roles = _editRoles(current, member);
    if (roles.isEmpty) return;
    final nameController = TextEditingController(text: member.displayName);
    final passwordController = TextEditingController();
    StaffRole? selectedRole = roles.contains(member.role)
        ? member.role
        : roles.first;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit ${member.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<StaffRole>(
                initialValue: selectedRole,
                items: roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(_roleLabel(role)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() => selectedRole = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Role',
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => error = 'Name is required');
                  return;
                }
                final pwd = passwordController.text.trim();
                final res = notifier.updateStaffAccount(
                  member.id,
                  displayName: name,
                  role: selectedRole,
                  password: pwd.isEmpty ? null : pwd,
                );
                if (res != null) {
                  setDialogState(() => error = res);
                } else {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated ${member.displayName}')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    passwordController.dispose();
  }

  Future<void> _confirmDelete(AppNotifier notifier, StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${member.displayName}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final error = notifier.deleteStaffAccount(member.id);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted ${member.displayName}')));
    }
  }

  String _roleLabel(StaffRole role) {
    switch (role) {
      case StaffRole.admin:
        return 'Admin';
      case StaffRole.owner:
        return 'Owner';
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.worker:
        return 'Worker';
    }
  }
}
