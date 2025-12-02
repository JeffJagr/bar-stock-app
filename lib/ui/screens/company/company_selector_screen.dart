import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/company_repository.dart';
import '../../../models/cloud_user_role.dart';
import '../../../models/company.dart';

class CompanySelectorScreen extends StatefulWidget {
  final String currentUserId;
  final String? currentUserEmail;
  final void Function(String companyId, Company company) onCompanySelected;
  final bool allowCreate;
  final Widget? emptyPlaceholder;
  final CloudUserRole? role;
  final bool autoSelectSingle;

  const CompanySelectorScreen({
    super.key,
    required this.currentUserId,
    this.currentUserEmail,
    required this.onCompanySelected,
    this.allowCreate = true,
    this.emptyPlaceholder,
    this.role,
    this.autoSelectSingle = true,
  });

  @override
  State<CompanySelectorScreen> createState() => _CompanySelectorScreenState();
}

class _CompanySelectorScreenState extends State<CompanySelectorScreen> {
  final CompanyRepository _repository = CompanyRepository();
  bool _creatingCompany = false;
  final TextEditingController _companyNameController = TextEditingController();
  String? _error;
  String? _autoSelectedCompanyId;

  @override
  void dispose() {
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _createCompany() async {
    final name = _companyNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Company name cannot be empty');
      return;
    }
    setState(() => _creatingCompany = true);
    try {
      final companyId = await _repository.createCompany(
        name: name,
        ownerUserId: widget.currentUserId,
      );
      final company = await _repository.fetchCompany(companyId);
      if (!mounted) return;
      _companyNameController.clear();
      setState(() {
        _creatingCompany = false;
        _error = null;
      });
      if (company != null) {
        widget.onCompanySelected(company.companyId, company);
      }
    } catch (err) {
      setState(() {
        _creatingCompany = false;
        _error = 'Failed to create company';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Company>>(
      stream: _repository.streamUserCompanies(widget.currentUserId),
      builder: (context, snapshot) {
        final companies = snapshot.data ?? [];
        if (widget.autoSelectSingle &&
            companies.length == 1 &&
            _autoSelectedCompanyId != companies.first.companyId) {
          _autoSelectedCompanyId = companies.first.companyId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onCompanySelected(
              companies.first.companyId,
              companies.first,
            );
          });
        }
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
                companies.isEmpty;
        if (snapshot.hasError) {
          _error ??= 'Failed to load companies';
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select a company',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (widget.role == CloudUserRole.owner)
                Text(
                  'Share the Business ID with staff; join codes are no longer required.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : companies.isEmpty
                        ? (widget.emptyPlaceholder ??
                            Center(
                              child: Text(
                                widget.allowCreate
                                    ? 'No companies yet. Create one to get started.'
                                    : 'No companies linked to this account yet.',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ))
                        : ListView.builder(
                            itemCount: companies.length,
                            itemBuilder: (context, index) {
                              final company = companies[index];
                              final isOwner = widget.role == CloudUserRole.owner;
                              final subtitle = isOwner
                                  ? 'Business ID: ${company.businessId}'
                                  : 'Owner: ${company.ownerUserId}';
                              return Card(
                                child: ListTile(
                                  title: Text(company.name),
                                  subtitle: Text(subtitle),
                                  onTap: () => widget.onCompanySelected(
                                      company.companyId, company),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              if (widget.allowCreate) ...[
                Text(
                  'Create a new company',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _companyNameController,
                  decoration: InputDecoration(
                    labelText: 'Company name',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _creatingCompany ? null : _createCompany,
                  icon: _creatingCompany
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_business),
                  label: Text(_creatingCompany ? 'Creating...' : 'Create Company'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _copyJoinCode(BuildContext context, String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied code $code')),
    );
  }
}
