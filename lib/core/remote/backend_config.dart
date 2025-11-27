/// Shared configuration for backend integrations.
class BackendConfig {
  /// Temporary single-bar identifier used for syncing AppState to Firestore.
  static const String defaultBarId = 'default_bar';
  /// Field name recorded for the owner/manager UID once Firebase Auth is live.
  static const String ownerUidField = 'ownerUid';

  /// Firestore collection containing bar state documents.
  static const String barsCollection = 'bars';

  /// Field name that stores the serialized [AppState] JSON blob.
  static const String stateField = 'state';

  /// Optional field to track server timestamps for future conflict resolution.
  static const String updatedAtField = 'updatedAt';
}
