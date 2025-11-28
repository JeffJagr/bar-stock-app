import 'package:flutter/material.dart';

import '../../../data/company_repository.dart';

class JoinCompanyCodeDialog extends StatefulWidget {
  final CompanyRepository repository;
  final String userId;
  final String? userEmail;

  const JoinCompanyCodeDialog({
    super.key,
    required this.repository,
    required this.userId,
    this.userEmail,
  });

  @override
  State<JoinCompanyCodeDialog> createState() => _JoinCompanyCodeDialogState();
}

class _JoinCompanyCodeDialogState extends State<JoinCompanyCodeDialog> {
  final _codeController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = 'Enter a valid company code');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final company = await widget.repository.fetchCompanyByCode(code);
      if (company == null) {
        setState(() {
          _joining = false;
          _error = 'No company found for this code';
        });
        return;
      }
      await widget.repository.joinCompany(
        company: company,
        userId: widget.userId,
        email: widget.userEmail,
      );
      if (!mounted) return;
      Navigator.of(context).pop(company);
    } catch (err) {
      setState(() {
        _joining = false;
        _error = 'Failed to join company';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join company'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter the company code provided by your manager.'),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Company code',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _joining ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _joining ? null : _submit,
          child: _joining
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}
