/// Secure placeholders for secrets that must be provided outside of source control.
const String defaultAdminPin = String.fromEnvironment(
  'DEFAULT_ADMIN_PIN',
  defaultValue: 'CHANGE_ME_PIN',
);

/// Firebase-authenticated admin accounts seeded outside the local PIN flow.
const Map<String, String> firebaseAdminAccounts = {
  'nik.jefremov@gmail.com': 'Nik Jefremov',
};
