import 'package:firebase_auth/firebase_auth.dart';

import '../data/company_repository.dart';
import '../data/user_profile_repository.dart';
import 'error_reporter.dart';

/// Handles irreversible owner account deletion plus company data cleanup.
class AccountDeletionController {
  AccountDeletionController({
    CompanyRepository? companyRepository,
    UserProfileRepository? userProfileRepository,
    FirebaseAuth? auth,
  })  : _companyRepository = companyRepository ?? CompanyRepository(),
        _userProfileRepository = userProfileRepository ?? UserProfileRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  final CompanyRepository _companyRepository;
  final UserProfileRepository _userProfileRepository;
  final FirebaseAuth _auth;

  /// Deletes the owner profile, company data, and attempts to delete the auth user.
  /// If auth deletion fails due to re-auth requirements, the account data is still
  /// removed and the caller should force sign-out to prevent access.
  Future<void> deleteOwnerAndCompany({
    required String userId,
    required String companyId,
  }) async {
    try {
      await _companyRepository.deleteCompanyCascade(companyId);
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'deleteCompanyCascade failed');
      rethrow;
    }

    try {
      await _userProfileRepository.deleteUser(userId);
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'deleteUserProfile failed');
      rethrow;
    }

    try {
      final current = _auth.currentUser;
      if (current != null && current.uid == userId) {
        await current.delete();
      }
    } catch (err, stack) {
      // Deleting auth user may require recent login; log but do not block.
      ErrorReporter.logException(err, stack, reason: 'auth user delete failed');
    }
  }
}
