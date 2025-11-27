import 'package:flutter/material.dart';
import '../../../data/company_repository.dart';
import '../../../models/company.dart';

class CompanySelectorScreen extends StatefulWidget {
  final String currentUserId;
  final void Function(String companyId, Company company) onCompanySelected;

  const CompanySelectorScreen({
    super.key,
    required this.currentUserId,
    required this.onCompanySelected,
  });

  @override
  State<CompanySelectorScreen> createState() => _CompanySelectorScreenState();
}

class _CompanySelectorScreenState extends State<CompanySelectorScreen> {
  final CompanyRepository _repository = CompanyRepository();
  bool _creatingCompany = false;
  final TextEditingController _companyNameController = TextEditingController();
  String? _error;

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
      final id = await _repository.createCompany(
        name: name,
        ownerUserId: widget.currentUserId,
      );
      if (!mounted) return;
      final company = Company(
        companyId: id,
        name: name,
        ownerUserId: widget.currentUserId,
        createdAt: DateTime.now(),
      );
      _companyNameController.clear();
      setState(() {
        _creatingCompany = false;
        _error = null;
      });
      widget.onCompanySelected(id, company);
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
      stream: _repository.watchUserCompanies(widget.currentUserId),
      builder: (context, snapshot) {
        final companies = snapshot.data ?? [];
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
              const SizedBox(height: 16),
              if (companies.isEmpty)
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Center(
                          child: Text(
                            'No companies yet. Create one to get started.',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: companies.length,
                    itemBuilder: (context, index) {
                      final company = companies[index];
                      return Card(
                        child: ListTile(
                          title: Text(company.name),
                          subtitle: Text('Owner: ${company.ownerUserId}'),
                          onTap: () =>
                              widget.onCompanySelected(company.companyId, company),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Text('Create a new company', style: Theme.of(context).textTheme.titleMedium),
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
          ),
        );
      },
    );
  }
}
