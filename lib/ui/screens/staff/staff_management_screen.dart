import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_notifier.dart';
import '../../../core/models/staff_member.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
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

  void _submit() {
    final login = _loginController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    if (login.isEmpty || name.isEmpty || password.length < 4) {
      setState(() {
        _error =
            'Login, name and password (min 4 chars) are required.';
      });
      return;
    }
    final notifier = context.read<AppNotifier>();
    final error =
        notifier.createStaffAccount(login, name, _selectedRole, password);
    if (error != null) {
      setState(() => _error = error);
    } else {
      setState(() {
        _error = null;
        _loginController.clear();
        _nameController.clear();
        _passwordController.clear();
        _selectedRole = StaffRole.worker;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff account created')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<AppNotifier>().state.staff.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create account',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Login',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<StaffRole>(
                      initialValue: _selectedRole,
                      items: StaffRole.values
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: staff.isEmpty
                  ? const Center(child: Text('No staff yet'))
                  : ListView.builder(
                      itemCount: staff.length,
                      itemBuilder: (context, index) {
                        final member = staff[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.displayName.isNotEmpty
                                  ? member.displayName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(member.displayName),
                          subtitle: Text(
                              '${member.login} • ${member.role.name.toUpperCase()}'),
                          trailing: Text(
                            _formatDate(member.createdAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
