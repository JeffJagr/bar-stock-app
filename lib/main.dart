import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:provider/provider.dart';

import 'core/app_logic.dart';
import 'core/app_notifier.dart';
import 'core/app_state.dart';
import 'core/app_storage.dart';
import 'core/config.dart';
import 'core/error_reporter.dart';
import 'core/models/order_item.dart';
import 'models/company.dart';
import 'models/company_member.dart';
import 'core/print_service.dart';
import 'core/remote/backend_config.dart';
import 'core/remote/remote_repository.dart';
import 'core/remote/remote_sync_service.dart';
import 'core/session_manager.dart';
import 'core/undo_manager.dart';
import 'core/web_refresh.dart';
import 'data/company_repository.dart';
import 'data/staff_repository.dart';
import 'data/user_profile_repository.dart';
import 'models/cloud_user_role.dart';
import 'ui/screens/auth/auth_landing_screen.dart';
import 'ui/screens/auth/firebase_email_auth_screen.dart';
import 'ui/screens/auth/staff_login_screen.dart';
import 'ui/screens/company/company_selector_screen.dart';
import 'ui/screens/company/company_settings_screen.dart';
import 'ui/screens/company/join_company_placeholder.dart';
import 'ui/screens/company/join_company_code_dialog.dart';
import 'ui/screens/bar/bar_screen.dart';
import 'ui/screens/bar/low_screen.dart';
import 'ui/screens/legal/legal_screen.dart';
import 'ui/screens/history/history_screen.dart';
import 'ui/screens/orders/order_screen.dart';
import 'ui/screens/restock/restock_screen.dart';
import 'ui/screens/search/global_search_screen.dart';
import 'ui/screens/settings/account_deletion_screen.dart';
import 'ui/screens/staff/staff_management_screen.dart';
import 'ui/screens/statistics/statistics_screen.dart';
import 'ui/screens/warehouse/warehouse_screen.dart';
import 'ui/widgets/loading_overlay.dart';
import 'ui/widgets/print_preview_dialog.dart';
import 'ui/widgets/session_observer.dart';
import 'firebase_options.dart';
import 'models/staff_member.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = ErrorReporter.recordFlutterError;

    var firebaseReady = false;
    if (AppConfig.firebaseEnabled) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseReady = true;
      } catch (err, stack) {
        ErrorReporter.logException(
          err,
          stack,
          reason: 'Firebase initialization failed',
        );
      }
    }

    runApp(SmartBarApp(firebaseReady: firebaseReady));
  }, ErrorReporter.recordZoneError);
}

class SmartBarApp extends StatefulWidget {
  const SmartBarApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<SmartBarApp> createState() => _SmartBarAppState();
}

enum _AppMenuAction { search, statistics }
enum _AuthFlow { landing, ownerEmail, staffPin }

class _SmartBarAppState extends State<SmartBarApp> {
  static const Color _brandPrimary = Color(0xFF455A64);
  static const Color _brandPrimaryDark = Color(0xFF0D1B2A);
  bool _loading = true;
  bool _syncingCloud = false;
  int _selectedIndex = 0;
  CompanyMember? _activeStaff;
  String? _lastBusinessId;
  _AuthFlow _authFlow = _AuthFlow.landing;
  Company? _activeCompany;

  final PrintService _printService = const PrintService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  FirebaseAuth? _firebaseAuth;
  User? _firebaseUser;
  StreamSubscription<User?>? _authSubscription;
  final UserProfileRepository _userProfileRepository = UserProfileRepository();
  final CompanyRepository _companyRepository = CompanyRepository();
  final StaffRepository _staffRepository = StaffRepository();
  String _barId = BackendConfig.defaultBarId;
  late final RemoteRepository _remoteRepository;
  late final RemoteSyncService _remoteSyncService;
  late final AppNotifier _appNotifier;
  late final bool _firebaseAvailable;
  late final SessionManager _sessionManager;
  CloudUserRole? _selectedRoleChoice;

  AppState get _state => _appNotifier.state;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _brandPrimaryDark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _brandPrimaryDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _firebaseAvailable = widget.firebaseReady && AppConfig.firebaseEnabled;
    if (_firebaseAvailable) {
      _firebaseAuth = FirebaseAuth.instance;
      _remoteRepository = FirestoreRemoteRepository();
      _authSubscription =
          _firebaseAuth!.authStateChanges().listen(_handleAuthState);
    } else {
      _remoteRepository = const LocalRemoteRepository();
    }
    _remoteSyncService = RemoteSyncService(
      repository: _remoteRepository,
      onRemoteState: _handleRemoteState,
    );
    _appNotifier = AppNotifier(
      initialState: AppState.initial(),
      undoManager: UndoManager(),
      persistCallback: _persistToRepositories,
    );
    _appNotifier.addListener(_handleAppStateChanged);
    _sessionManager = SessionManager(
      onTimeout: _handleInactivityTimeout,
      ownerTimeout: const Duration(minutes: 30),
      staffTimeout: const Duration(minutes: 20),
      warningDuration: const Duration(seconds: 10),
    );
    AppStorage.setActiveBar(_barId);
    if (!_firebaseAvailable) {
      unawaited(_loadInitialForUser(_barId));
    }
  }

  Future<void> _handleAuthState(User? user) async {
    if (!_firebaseAvailable || !mounted) {
      return;
    }
    if (user == null) {
      await _remoteSyncService.dispose();
      _firebaseUser = null;
      _appNotifier.setCurrentUserId(null);
      _appNotifier.setCloudUserRole(null);
      _appNotifier.replaceState(AppState.initial());
      AppLogic.setCurrentStaff(null);
      AppStorage.setActiveBar(BackendConfig.defaultBarId);
      setState(() {
        _activeStaff = null;
        _selectedIndex = 0;
        _loading = false;
        _activeCompany = null;
        _selectedRoleChoice = null;
        _authFlow = _AuthFlow.landing;
      });
      return;
    }
    _firebaseUser = user;
    _appNotifier.setCurrentUserId(user.uid);
    CloudUserRole? role =
        await _userProfileRepository.fetchRole(user.uid);
    role ??= _selectedRoleChoice;
    if (role != null) {
      await _userProfileRepository.setRole(user.uid, role);
    }
    _appNotifier.setCloudUserRole(role);
    final resolvedFlow =
        _authFlow == _AuthFlow.staffPin ? _AuthFlow.staffPin : _AuthFlow.ownerEmail;
    setState(() {
      _loading = false;
      _activeStaff = null;
      _selectedIndex = 0;
      _selectedRoleChoice = role;
      _authFlow = resolvedFlow;
    });
  }

  Future<void> _loadInitialForUser(String companyId) async {
    setState(() {
      _loading = true;
      _selectedIndex = 0;
    });
    _barId = companyId;
    AppStorage.setActiveBar(_barId);
    AppState resolvedState;
    try {
      var loaded = await AppStorage.loadState();
      _ensureDefaultAdmin(loaded);

      final remote = await _loadRemoteStateWithTimeout();
      if (remote != null) {
        loaded = remote;
      } else {
        await _saveRemoteStateSoftly(loaded);
      }
      resolvedState = loaded;
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Failed to load initial state',
      );
      resolvedState = AppState.initial();
      _ensureDefaultAdmin(resolvedState);
    }

    try {
      AppStorage.setActiveBar(_barId);
      await AppStorage.saveState(resolvedState);
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Failed to cache state locally',
      );
    }

    resolvedState.activeCompanyId = companyId;
    _appNotifier.replaceState(resolvedState);
    if (!mounted) return;
    setState(() {
      _activeStaff = _activeStaff;
      _loading = false;
    });
    AppLogic.setCurrentStaff(null);
    if (_firebaseAvailable) {
      _remoteSyncService.start(_barId);
    }
    if (_activeCompany != null || _activeStaff != null) {
      _sessionManager.resetTimer();
    }
  }

  void _handleAppStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleCompanySelected(
    String companyId,
    Company company,
  ) async {
    if (!_firebaseAvailable || _firebaseAuth == null) return;
    final ownerMember = _ownerSessionMember(companyId);
    setState(() {
      _activeCompany = company;
      _activeStaff = ownerMember;
      _selectedIndex = 0;
    });
    AppLogic.setCurrentStaff(null);
    _appNotifier.setActiveCompanyId(companyId);
    _appNotifier.setCurrentStaffMember(ownerMember);
    await _remoteSyncService.dispose();
    await _loadInitialForUser(companyId);
    _sessionManager.startForOwner();
    await _appNotifier.startLiveStreams(companyId);
  }

  Future<void> _clearCompanySelection() async {
    await _remoteSyncService.dispose();
    await _appNotifier.stopLiveStreams();
    _barId = BackendConfig.defaultBarId;
    AppStorage.setActiveBar(_barId);
    _appNotifier.setActiveCompanyId(null);
    _appNotifier.setActiveStaffId(null);
    _appNotifier.replaceState(AppState.initial());
    AppLogic.setCurrentStaff(null);
    setState(() {
      _activeCompany = null;
      _activeStaff = null;
      _selectedIndex = 0;
      _loading = false;
    });
  }

  void _promptCompanySwitch(BuildContext ctx) {
    if (!_firebaseAvailable || _firebaseUser == null) return;
    showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Switch company'),
        content: const Text(
          'You will need to reselect a company and log in again. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _clearCompanySelection();
      }
    });
  }

  void _openCompanySettings(BuildContext context) {
    final companyId = _appNotifier.state.activeCompanyId;
    if (companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a company first')),
      );
      return;
    }
    final canRegenerate = _isOwner;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanySettingsScreen(
          companyId: companyId,
          repository: _companyRepository,
          canRegenerate: canRegenerate,
          canDeleteAccount: _isOwner,
          onDeleteAccount: () => _openAccountDeletion(context),
        ),
      ),
    );
  }

  Future<void> _showJoinCompanyDialog(BuildContext context) async {
    if (_firebaseUser == null) return;
    final joinedCompany = await showDialog<Company>(
      context: context,
      builder: (ctx) => JoinCompanyCodeDialog(
        repository: _companyRepository,
        userId: _firebaseUser!.uid,
        userEmail: _firebaseUser!.email,
      ),
    );
    if (joinedCompany != null) {
      await _handleCompanySelected(joinedCompany.companyId, joinedCompany);
    }
  }

  @override
  void dispose() {
    _appNotifier.removeListener(_handleAppStateChanged);
    _authSubscription?.cancel();
    _remoteSyncService.dispose();
    _appNotifier.stopLiveStreams();
    _sessionManager.cancelTimer();
    _appNotifier.dispose();
    super.dispose();
  }

  void _ensureDefaultAdmin(AppState state) {}

  bool get _hasManagementAccess {
    final role = (_activeStaff?.role ?? '').toLowerCase();
    if (role == 'owner' || role == 'manager') return true;
    // In offline/demo mode (no Firebase), allow management to keep local editing.
    if (!_firebaseAvailable) return true;
    return false;
  }

  bool get _isOwner => (_activeStaff?.role ?? '').toLowerCase() == 'owner';
  bool get _isManager => (_activeStaff?.role ?? '').toLowerCase() == 'manager';
  bool get _canAccessStaffManagement =>
      _activeStaff != null && (_isOwner || _isManager);

  void _persistState() {
    _appNotifier.persistState();
  }

  Future<void> _persistToRepositories(AppState state) async {
    AppStorage.setActiveBar(_barId);
    await AppStorage.saveState(state);
    unawaited(_appNotifier.syncToCloud(_barId));
  }

  void _onUndo(BuildContext ctx) {
    if (!_appNotifier.canUndoForRole(null)) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('No undo actions available')),
      );
      return;
    }
    final restored = _appNotifier.restoreLatestUndo(null);
    if (!restored) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('No undoable actions available')),
      );
      return;
    }
    AppLogic.setCurrentStaff(null);
    _persistState();
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(const SnackBar(content: Text('Last action undone')));
  }

  Future<AppState?> _loadRemoteStateWithTimeout() async {
    try {
      return await _remoteRepository
          .loadState(_barId)
          .timeout(const Duration(seconds: 5));
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Remote state load failed',
      );
      return null;
    }
  }

  Future<void> _saveRemoteStateSoftly(AppState state) async {
    try {
      await _remoteRepository
          .saveState(_barId, state)
          .timeout(const Duration(seconds: 5));
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Remote state save failed',
      );
    }
  }

  void _openSearch(BuildContext ctx) {
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const GlobalSearchScreen()));
  }

  void _openStatistics(BuildContext ctx) {
    if (!_hasManagementAccess) {
      _showManagementWarning(ctx);
      return;
    }
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const StatisticsScreen()));
  }

  void _handleRemoteState(AppState remoteState) {
    if (!mounted) return;
    final localJson = _appNotifier.state.toJson();
    final remoteJson = remoteState.toJson();
    if (mapEquals(localJson, remoteJson)) {
      return;
    }
    _appNotifier.replaceState(remoteState);
    AppLogic.setCurrentStaff(null);
  }

  Future<void> _logoutAll() async {
    final hadSession = _firebaseUser != null ||
        _activeStaff != null ||
        _appNotifier.currentUserId != null ||
        _appNotifier.state.activeCompanyId != null;
    setState(() {
      _loading = true;
    });
    await _remoteSyncService.dispose();
    await _appNotifier.stopLiveStreams();
    _appNotifier.logoutAll();
    AppLogic.setCurrentStaff(null);
    _firebaseUser = null;
    _activeCompany = null;
    _activeStaff = null;
    _selectedIndex = 0;
    _authFlow = _AuthFlow.landing;
    _selectedRoleChoice = null;
    _lastBusinessId = null;
    _sessionManager.cancelTimer();
    AppStorage.setActiveBar(BackendConfig.defaultBarId);
    if (_firebaseAvailable) {
      try {
        await _firebaseAuth?.signOut();
      } catch (err, stack) {
        ErrorReporter.logException(
          err,
          stack,
          reason: 'Logout failed',
        );
      }
    }
    if (mounted && hadSession) {
      setState(() {
        _loading = false;
      });
      final messenger = ScaffoldMessenger.maybeOf(
        _navigatorKey.currentContext ?? context,
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text('Logged out')),
      );
    } else if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showManagementWarning(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Owner or manager permissions required')),
    );
  }

  void _openHistory(BuildContext ctx) {
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  void _openLegal(BuildContext ctx) {
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const LegalScreen()));
  }

  void _openAccountDeletion(BuildContext ctx) {
    if (!_isOwner || _activeCompany == null || _firebaseUser == null) {
      return;
    }
    Navigator.of(
      ctx,
    ).push(
      MaterialPageRoute(
        builder: (_) => AccountDeletionScreen(
          company: _activeCompany!,
          userId: _firebaseUser!.uid,
          onDeleted: () async {
            await _logoutAll();
          },
        ),
      ),
    );
  }

  Future<void> _handleStaffLogin(
    String businessId,
    String pin,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(
          _navigatorKey.currentContext ?? context) ??
        ScaffoldMessenger.maybeOf(context);
    setState(() => _loading = true);
    if (_firebaseAvailable &&
        _firebaseAuth != null &&
        _firebaseAuth!.currentUser == null) {
      try {
        await _firebaseAuth!.signInAnonymously();
      } catch (err, stack) {
        ErrorReporter.logException(
          err,
          stack,
          reason: 'Anonymous sign-in for staff failed',
        );
      }
    }
    final company =
        await _companyRepository.getCompanyByBusinessId(businessId);
    if (company == null) {
      setState(() => _loading = false);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Invalid Business ID')),
      );
      return;
    }
    final staffMember = await _staffRepository.getStaffByPin(
      companyId: company.companyId,
      pin: pin,
    );
    if (staffMember == null) {
      setState(() => _loading = false);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Invalid PIN')),
      );
      return;
    }
    final member = _mapStaffToCompanyMember(staffMember);
    if (member.disabled) {
      setState(() => _loading = false);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Staff member disabled')),
      );
      return;
    }
    setState(() {
      _activeCompany = company;
      _activeStaff = member;
      _selectedIndex = 0;
      _authFlow = _AuthFlow.staffPin;
      _lastBusinessId = company.businessId;
    });
    _appNotifier.setActiveCompanyId(company.companyId);
    _appNotifier.setCurrentStaffMember(member);
    await _remoteSyncService.dispose();
    await _loadInitialForUser(company.companyId);
    _sessionManager.startForStaff();
    await _appNotifier.startLiveStreams(company.companyId);
    setState(() => _loading = false);
  }

  void _openStaffManagement(BuildContext ctx) {
    if (!_canAccessStaffManagement) {
      _showStaffAccessWarning(ctx);
      return;
    }
    final companyId = _appNotifier.state.activeCompanyId;
    if (companyId == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Select a company first')),
      );
      return;
    }
    Navigator.of(
      ctx,
    ).push(
      MaterialPageRoute(
        builder: (_) => StaffManagementScreen(
          companyId: companyId,
          businessId: _activeCompany?.businessId,
          repository: _staffRepository,
        ),
      ),
    );
  }

  void _showStaffAccessWarning(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text(
          'Staff management is available to owners or managers',
        ),
      ),
    );
  }

  void _onManualSync(BuildContext ctx) {
    final messenger = ScaffoldMessenger.of(ctx);
    if (!_firebaseAvailable ||
        _appNotifier.currentUserId == null ||
        _appNotifier.state.activeCompanyId == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Cloud sync available only when logged in and company selected')),
      );
      return;
    }
    setState(() => _syncingCloud = true);
    Future(() async {
      final pushOk = await _appNotifier.syncToCloud(_barId);
      if (!pushOk) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to upload changes. Working offline for now.'),
          ),
        );
      }
      final remoteState = await _appNotifier.fetchCloudState(_barId);
      if (!mounted) return;
      if (remoteState != null) {
        _appNotifier.applyRemoteState(remoteState);
        await _persistToRepositories(_appNotifier.state);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Cloud sync failed')),
        );
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() => _syncingCloud = false);
      }
    });
  }

  CompanyMember _ownerSessionMember(String companyId) {
    final now = DateTime.now();
    return CompanyMember(
      memberId: _firebaseUser?.uid ?? 'owner-session',
      companyId: companyId,
      displayName: _firebaseUser?.email ?? 'Owner',
      role: 'owner',
      pinHash: '',
      pinSalt: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  CompanyMember _mapStaffToCompanyMember(CompanyStaffMember staff) {
    return CompanyMember(
      memberId: staff.staffId,
      companyId: staff.companyId,
      displayName: staff.displayName,
      role: staff.role,
      pinHash: staff.pinHash,
      pinSalt: staff.companyId,
      createdAt: staff.createdAt,
      updatedAt: staff.updatedAt,
      disabled: !staff.isActive,
    );
  }

  Future<void> _handleInactivityTimeout() async {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null || !mounted) {
      await _logoutAll();
      return;
    }
    final countdown = ValueNotifier<int>(_sessionManager.warningDuration.inSeconds);
    Timer? ticker;
    Timer? autoLogout;
    bool acknowledged = false;

    void cleanup() {
      ticker?.cancel();
      autoLogout?.cancel();
      countdown.dispose();
    }

    ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = countdown.value - 1;
      if (next >= 0) {
        countdown.value = next;
      }
    });

    autoLogout = Timer(_sessionManager.warningDuration, () async {
      if (acknowledged) return;
      acknowledged = true;
      Navigator.of(ctx, rootNavigator: true).pop();
      await _logoutAll();
    });

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Inactivity warning'),
            content: ValueListenableBuilder<int>(
              valueListenable: countdown,
              builder: (_, seconds, child) {
                return Text(
                  'You will be logged out due to inactivity in $seconds seconds.',
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (acknowledged) return;
                  acknowledged = true;
                  Navigator.of(dialogCtx).pop();
                  cleanup();
                  _sessionManager.resetTimer();
                },
                child: const Text('Stay signed in'),
              ),
              TextButton(
                onPressed: () async {
                  if (acknowledged) return;
                  acknowledged = true;
                  Navigator.of(dialogCtx).pop();
                  cleanup();
                  await _logoutAll();
                },
                child: const Text('Log out now'),
              ),
            ],
          ),
        );
      },
    );

    cleanup();
  }

  void _onCloudDownload(BuildContext ctx) {
    final messenger = ScaffoldMessenger.of(ctx);
    if (!_firebaseAvailable ||
        _appNotifier.currentUserId == null ||
        _appNotifier.state.activeCompanyId == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Cloud sync available only when logged in and company selected')),
      );
      return;
    }
    setState(() => _syncingCloud = true);
    _appNotifier.syncFromCloud(_barId).then((success) async {
      if (!mounted) return;
      if (success) {
        await _persistToRepositories(_appNotifier.state);
        messenger.showSnackBar(
          const SnackBar(content: Text('Latest cloud data loaded')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to load cloud data')),
        );
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() => _syncingCloud = false);
      }
    });
  }

  void _onPrint(BuildContext ctx) {
    final section = _printService.sectionForTab(_selectedIndex);
    if (section == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Nothing to export for this tab')),
      );
      return;
    }
    PrintPreviewDialog.show(ctx, _state, section);
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _lowBadge(int? count, {Color color = Colors.red}) {
    final display = count != null ? count.clamp(0, 99) : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
      child: display == null
          ? null
          : Text(
              display.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_authFlow == _AuthFlow.staffPin && _activeStaff == null) {
      return StaffLoginScreen(
        initialBusinessId: _lastBusinessId,
        onSubmit: (businessId, pin) => _handleStaffLogin(businessId, pin),
        onBack: () {
          setState(() {
            _authFlow = _AuthFlow.landing;
            _selectedRoleChoice = null;
          });
        },
      );
    }

      if (_firebaseAvailable &&
          _firebaseAuth != null &&
          _firebaseUser == null &&
          _authFlow != _AuthFlow.staffPin) {
      if (_selectedRoleChoice == null || _authFlow == _AuthFlow.landing) {
        return AuthLandingScreen(
          onOwnerLogin: () {
            setState(() {
              _selectedRoleChoice = CloudUserRole.owner;
              _authFlow = _AuthFlow.ownerEmail;
              _appNotifier.setCloudUserRole(CloudUserRole.owner);
            });
          },
          onStaffLogin: () {
            setState(() {
              _selectedRoleChoice = CloudUserRole.worker;
              _authFlow = _AuthFlow.staffPin;
            });
          },
          onLegal: () => _openLegal(context),
        );
      }
      return FirebaseEmailAuthScreen(
        auth: _firebaseAuth!,
        role: CloudUserRole.owner,
        onBack: () {
          setState(() {
            _selectedRoleChoice = null;
            _authFlow = _AuthFlow.landing;
            _appNotifier.setCloudUserRole(null);
          });
        },
      );
    }

    final cloudRole = _appNotifier.cloudUserRole ?? _selectedRoleChoice;

    final needsCompanySelection = _firebaseAvailable &&
        _firebaseUser != null &&
        (_appNotifier.state.activeCompanyId == null);
    if (needsCompanySelection) {
      final allowCreate = cloudRole != CloudUserRole.worker;
      return CompanySelectorScreen(
        currentUserId: _firebaseUser!.uid,
        currentUserEmail: _firebaseUser!.email,
        onCompanySelected: _handleCompanySelected,
        allowCreate: allowCreate,
        emptyPlaceholder: allowCreate
            ? null
            : JoinCompanyPlaceholder(
                onRefresh: () => setState(() {}),
                onSignOut: () => _logoutAll(),
                onEnterCode: () => _showJoinCompanyDialog(context),
              ),
        role: cloudRole,
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeStaff == null) {
      return StaffLoginScreen(
        initialBusinessId: _lastBusinessId,
        onSubmit: (businessId, pin) => _handleStaffLogin(businessId, pin),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return BarScreen(
          canEdit: _hasManagementAccess,
          onRequireManager: () => _showManagementWarning(context),
        );
      case 1:
        return const LowScreen();
      case 2:
        return const RestockScreen();
      case 3:
        return WarehouseScreen(
          canEdit: _hasManagementAccess,
          onRequireManager: () => _showManagementWarning(context),
        );
      case 4:
        return const OrderScreen();
      default:
        return const Center(child: Text('Coming soon...'));
    }
  }

  String _title() {
    switch (_selectedIndex) {
      case 0:
        return 'Bar';
      case 1:
        return 'Low';
      case 2:
        return 'Restock';
      case 3:
        return 'Warehouse';
      case 4:
        return 'Orders';
      default:
        return 'Smart Bar Stock';
    }
  }

  List<Widget> _buildActions(BuildContext ctx, bool hasOpenOrders) {
    final actions = <Widget>[];

    if (_activeStaff != null) {
      final companyLabel =
          _activeCompany?.name ?? _appNotifier.state.activeCompanyId;

      actions.addAll([
        if (companyLabel != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                companyLabel,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              _activeStaff!.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        PopupMenuButton<_AppMenuAction>(
          tooltip: 'Search & statistics',
          icon: const Icon(Icons.search),
          onSelected: (action) {
            switch (action) {
              case _AppMenuAction.search:
                _openSearch(ctx);
                break;
              case _AppMenuAction.statistics:
                _openStatistics(ctx);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _AppMenuAction.search,
              child: Text('Global search'),
            ),
            PopupMenuItem(
              value: _AppMenuAction.statistics,
              enabled: _hasManagementAccess,
              child: const Text('Statistics & analytics'),
            ),
          ],
        ),
        if (supportsWebRefresh)
          IconButton(
            tooltip: 'Refresh web app',
            icon: const Icon(Icons.refresh),
            onPressed: refreshWebApp,
          ),
        if (_isOwner || _isManager)
          IconButton(
            tooltip: 'Company settings',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => _openCompanySettings(ctx),
          ),
        if (_firebaseAvailable && _firebaseUser != null)
          IconButton(
            tooltip: 'Switch company',
            icon: const Icon(Icons.apartment),
            onPressed: _isOwner ? () => _promptCompanySwitch(ctx) : null,
          ),
        IconButton(
          tooltip: 'Download cloud data',
          icon: const Icon(Icons.cloud_download),
          onPressed: () => _onCloudDownload(ctx),
        ),
        IconButton(
          tooltip: 'Sync from cloud',
          icon: const Icon(Icons.sync),
          onPressed: () => _onManualSync(ctx),
        ),
        IconButton(
          tooltip: 'Print',
          icon: const Icon(Icons.print),
          onPressed: () => _onPrint(ctx),
        ),
        IconButton(
          tooltip: 'Undo last action',
          icon: const Icon(Icons.undo),
          onPressed: !_appNotifier.canUndoForRole(null)
              ? null
              : () => _onUndo(ctx),
        ),
        IconButton(
          tooltip: 'History',
          icon: const Icon(Icons.history),
          onPressed: () => _openHistory(ctx),
        ),
        if (_isOwner)
          IconButton(
            tooltip: 'Delete my account',
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _openAccountDeletion(ctx),
          ),
        if (_canAccessStaffManagement)
          IconButton(
            tooltip: 'Staff accounts',
            icon: const Icon(Icons.group),
            onPressed: () => _openStaffManagement(ctx),
          ),
        IconButton(
          tooltip: 'Log out',
          icon: const Icon(Icons.logout),
          onPressed: () => _logoutAll(),
        ),
      ]);
    }

    actions.add(
      IconButton(
        tooltip: 'Privacy & Terms',
        icon: const Icon(Icons.privacy_tip_outlined),
        onPressed: () => _openLegal(ctx),
      ),
    );

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final hasOpenOrders = _state.orders.any(
      (o) => o.status != OrderStatus.delivered,
    );
    final shortcuts = <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
          const _OpenSearchIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyH):
          const _OpenHistoryIntent(),
    };

    return ChangeNotifierProvider<AppNotifier>.value(
      value: _appNotifier,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Smart Bar Stock',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: _brandPrimary,
          appBarTheme: const AppBarTheme(
            backgroundColor: _brandPrimary,
            foregroundColor: Colors.white,
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: _brandPrimaryDark,
            indicatorColor: Colors.white24,
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(color: Colors.white),
            ),
            iconTheme: WidgetStatePropertyAll(
              IconThemeData(color: Colors.white),
            ),
          ),
        ),
        scrollBehavior: const _AppScrollBehavior(),
        builder: (context, child) {
          final content = Shortcuts(
            shortcuts: shortcuts,
            child: Actions(
              actions: {
                _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
                  onInvoke: (_) {
                    final navCtx = _navigatorKey.currentContext;
                    if (navCtx != null) {
                      _openSearch(navCtx);
                    }
                    return null;
                  },
                ),
                _OpenHistoryIntent: CallbackAction<_OpenHistoryIntent>(
                  onInvoke: (_) {
                    final navCtx = _navigatorKey.currentContext;
                    if (navCtx != null) {
                      _openHistory(navCtx);
                    }
                    return null;
                  },
                ),
              },
              child: Focus(
                autofocus: true,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
          final guarded = SessionObserver(
            auth: _firebaseAuth,
            notifier: _appNotifier,
            onSignedOut: _logoutAll,
            onInvalidState: _logoutAll,
            child: content,
          );
          final activityGuard = Listener(
            onPointerDown: (_) => _sessionManager.resetTimer(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _sessionManager.resetTimer();
                return false;
              },
              child: guarded,
            ),
          );
          return LoadingOverlay(
            isLoading: _loading || _syncingCloud,
            message: _loading ? 'Loading data...' : 'Syncing from cloud...',
            child: activityGuard,
          );
        },
        home: Builder(
          builder: (ctx) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Smart Bar Stock - ${_title()}'),
                actions: _buildActions(ctx, hasOpenOrders),
              ),
              body: _buildBody(ctx),
              bottomNavigationBar: _activeStaff == null
                  ? null
                  : BottomNavigationBar(
                      currentIndex: _selectedIndex,
                      onTap: _onNavTap,
                      type: BottomNavigationBarType.fixed,
                      selectedFontSize: 13,
                      unselectedFontSize: 11,
                      showUnselectedLabels: true,
                      selectedIconTheme: const IconThemeData(size: 28),
                      unselectedIconTheme: const IconThemeData(size: 24),
                      items: [
                        BottomNavigationBarItem(
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.local_bar),
                              if (AppLogic.lowItems(_state).isNotEmpty)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: _lowBadge(AppLogic.lowItems(_state).length),
                                ),
                            ],
                          ),
                          label: 'Bar',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.warning_amber),
                          label: 'Low',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.playlist_add_check),
                          label: 'Restock',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.warehouse),
                          label: 'Warehouse',
                        ),
                        BottomNavigationBarItem(
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.shopping_cart),
                              if (hasOpenOrders)
                                Positioned(
                                  right: -1,
                                  top: -1,
                                  child: _lowBadge(null, color: Colors.red),
                                ),
                            ],
                          ),
                          label: 'Orders',
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

class _OpenHistoryIntent extends Intent {
  const _OpenHistoryIntent();
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final isDesktop = kIsWeb ||
        {TargetPlatform.macOS, TargetPlatform.linux, TargetPlatform.windows}
            .contains(defaultTargetPlatform);
    if (!isDesktop) {
      return super.buildScrollbar(context, child, details);
    }
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      child: child,
    );
  }
}
