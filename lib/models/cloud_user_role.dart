enum CloudUserRole { owner, worker }

extension CloudUserRoleLabel on CloudUserRole {
  String get label {
    switch (this) {
      case CloudUserRole.owner:
        return 'Business Owner';
      case CloudUserRole.worker:
        return 'Worker / Staff';
    }
  }
}
