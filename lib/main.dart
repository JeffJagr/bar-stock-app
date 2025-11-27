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
import 'core/models/history_entry.dart';
import 'core/models/order_item.dart';
import 'core/models/staff_member.dart';
import 'core/print_service.dart';
import 'core/remote/backend_config.dart';
import 'core/remote/remote_repository.dart';
import 'core/remote/remote_sync_service.dart';
import 'core/security/security_config.dart';
import 'core/undo_manager.dart';
import 'core/web_refresh.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/bar/bar_screen.dart';
import 'ui/screens/bar/low_screen.dart';
import 'ui/screens/history/history_screen.dart';
import 'ui/screens/orders/order_screen.dart';
import 'ui/screens/restock/restock_screen.dart';
import 'ui/screens/search/global_search_screen.dart';
import 'ui/screens/staff/staff_management_screen.dart';
import 'ui/screens/statistics/statistics_screen.dart';
import 'ui/screens/warehouse/warehouse_screen.dart';
import 'ui/widgets/loading_overlay.dart';
import 'ui/widgets/print_preview_dialog.dart';
import 'firebase_options.dart';

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

class _SmartBarAppState extends State<SmartBarApp> {
  bool _loading = true;
  bool _syncingCloud = false;
  int _selectedIndex = 0;
  StaffMember? _activeStaff;
  String? _authError;
  bool _authBusy = false;

  final PrintService _printService = const PrintService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  FirebaseAuth? _firebaseAuth;
  String _barId = BackendConfig.defaultBarId;
  late final RemoteRepository _remoteRepository;
  late final RemoteSyncService _remoteSyncService;
  late final AppNotifier _appNotifier;
  late final bool _firebaseAvailable;

  AppState get _state => _appNotifier.state;

  @override
  void initState() {
    super.initState();
    _firebaseAvailable = widget.firebaseReady && AppConfig.firebaseEnabled;
    if (_firebaseAvailable) {
      _firebaseAuth = FirebaseAuth.instance;
      _remoteRepository = FirestoreRemoteRepository();
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
    AppStorage.setActiveBar(_barId);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    AppState resolvedState;
    try {
      var loaded = await AppStorage.loadState();
      _ensureDefaultAdmin(loaded);

      final firebaseUser = _firebaseAuth?.currentUser;
      if (firebaseUser != null) {
        _barId = firebaseUser.uid;
        AppStorage.setActiveBar(_barId);
      }

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

    _appNotifier.replaceState(resolvedState);
    if (!mounted) return;
    final resolvedStaff = _staffFromState(
      resolvedState,
      resolvedState.activeStaffId,
    );
    setState(() {
      _activeStaff = resolvedStaff;
      _loading = false;
    });
    AppLogic.setCurrentStaff(resolvedStaff);
    if (_firebaseAvailable) {
      _remoteSyncService.start(_barId);
    }
  }

  void _handleAppStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _appNotifier.removeListener(_handleAppStateChanged);
    _appNotifier.dispose();
    _remoteSyncService.dispose();
    super.dispose();
  }

  void _ensureDefaultAdmin(AppState state) {
    final hasAdmin = state.staff.any(
      (member) => member.role == StaffRole.admin,
    );
    if (hasAdmin) return;
    state.staff.add(
      StaffMember.create(
        login: 'admin',
        displayName: 'Admin',
        role: StaffRole.admin,
        password: defaultAdminPin,
      ),
    );
  }

  bool get _hasManagementAccess {
    final role = _activeStaff?.role;
    return role == StaffRole.admin ||
        role == StaffRole.owner ||
        role == StaffRole.manager;
  }

  bool get _isAdmin => _activeStaff?.role == StaffRole.admin;
  bool get _isOwner => _activeStaff?.role == StaffRole.owner;
  bool get _isManager => _activeStaff?.role == StaffRole.manager;
  bool get _canAccessStaffManagement =>
      _activeStaff != null && (_isAdmin || _isOwner || _isManager);

  void _persistState() {
    _appNotifier.persistState();
  }

  Future<void> _persistToRepositories(AppState state) async {
    AppStorage.setActiveBar(_barId);
    await AppStorage.saveState(state);
    unawaited(_appNotifier.syncToCloud(_barId));
  }

  void _onUndo(BuildContext ctx) {
    final role = _activeStaff?.role;
    if (!_appNotifier.canUndoForRole(role)) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('No undo actions available')),
      );
      return;
    }
    final restored = _appNotifier.restoreLatestUndo(role);
    if (!restored) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('No undoable actions available')),
      );
      return;
    }
    AppLogic.setCurrentStaff(_activeStaff);
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

  void _handleLogin(String login, String password) async {
    setState(() {
      _authBusy = true;
      _authError = null;
    });

    final normalized = login.trim().toLowerCase();
    StaffMember? staff = _findStaffByLogin(normalized);

    if (staff == null) {
      try {
        staff = await _maybeProvisionFirebaseAdmin(normalized, password);
      } on FirebaseAuthException {
        setState(() {
          _authBusy = false;
          _authError = 'Invalid credentials';
        });
        return;
      }
      if (staff == null) {
        setState(() {
          _authBusy = false;
          _authError = 'User not found';
        });
        return;
      }
    }

    if (firebaseAdminAccounts.containsKey(normalized) &&
        staff.role != StaffRole.admin) {
      staff.role = StaffRole.admin;
      _persistState();
    }

    if (!staff.verifyPassword(password)) {
      setState(() {
        _authBusy = false;
        _authError = 'Invalid credentials';
      });
      return;
    }

    setState(() {
      _authBusy = false;
      _authError = null;
      _activeStaff = staff;
    });
    _appNotifier.setActiveStaffId(staff.id);

    AppLogic.setCurrentStaff(staff);
    AppLogic.logCustomAction(
      _state,
      action: '${staff.displayName} logged in',
      kind: HistoryKind.auth,
      actionType: HistoryActionType.login,
      actor: staff,
    );
    _signInWithFirebase(login, password, staff);
    _persistState();
  }

  Future<void> _signInWithFirebase(
    String email,
    String password,
    StaffMember staff,
  ) async {
    if (!_firebaseAvailable || _firebaseAuth == null) return;
    try {
      final credential = await _firebaseAuth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _switchBar(user.uid, preferredStaff: staff);
      }
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Firebase auth sign in failed',
      );
    }
  }

  StaffMember? _findStaffByLogin(String login) {
    for (final member in _state.staff) {
      if (member.login == login) {
        return member;
      }
    }
    return null;
  }

  Future<StaffMember?> _maybeProvisionFirebaseAdmin(
    String login,
    String password,
  ) async {
    final displayName = firebaseAdminAccounts[login];
    if (displayName == null) return null;
    if (!_firebaseAvailable || _firebaseAuth == null) return null;
    final credential = await _firebaseAuth!.signInWithEmailAndPassword(
      email: login,
      password: password,
    );
    final resolvedName = credential.user?.displayName;
    final creationError = _appNotifier.createStaffAccount(
      login,
      (resolvedName?.isNotEmpty ?? false) ? resolvedName! : displayName,
      StaffRole.admin,
      password,
    );
    if (creationError != null && creationError.isNotEmpty) {
      ErrorReporter.logMessage(
        'Provisioning admin for $login failed: $creationError',
      );
    }
    return _findStaffByLogin(login);
  }

  StaffMember? _staffFromState(AppState state, String? staffId) {
    if (staffId == null) return null;
    for (final member in state.staff) {
      if (member.id == staffId) {
        return member;
      }
    }
    return null;
  }

  void _handleRemoteState(AppState remoteState) {
    if (!mounted) return;
    final localJson = _appNotifier.state.toJson();
    final remoteJson = remoteState.toJson();
    if (mapEquals(localJson, remoteJson)) {
      return;
    }
    final remoteStaff = _staffFromState(remoteState, remoteState.activeStaffId);
    setState(() {
      _activeStaff = remoteStaff;
    });
    _appNotifier.replaceState(remoteState);
    AppLogic.setCurrentStaff(remoteStaff);
  }

  Future<void> _switchBar(
    String newBarId, {
    StaffMember? preferredStaff,
    bool clearActiveStaff = false,
  }) async {
    if (!_firebaseAvailable) return;
    if (_barId == newBarId) {
      AppStorage.setActiveBar(_barId);
      _remoteSyncService.start(_barId);
      return;
    }
    _barId = newBarId;
    AppStorage.setActiveBar(_barId);
    var nextState = await _remoteRepository.loadState(_barId);
    if (nextState == null) {
      nextState = _appNotifier.state.copy();
      await _remoteRepository.saveState(_barId, nextState);
    }
    if (clearActiveStaff) {
      nextState.activeStaffId = null;
    } else if (preferredStaff != null) {
      nextState.activeStaffId = preferredStaff.id;
    }
    final resolvedStaff =
        preferredStaff ?? _staffFromState(nextState, nextState.activeStaffId);
    if (!mounted) return;
    _appNotifier.replaceState(nextState);
    setState(() {
      _activeStaff = resolvedStaff;
    });
    AppLogic.setCurrentStaff(resolvedStaff);
    if (_firebaseAvailable) {
      _remoteSyncService.start(_barId);
    }
  }

  void _logout(BuildContext context) {
    final staff = _activeStaff;
    if (staff != null) {
      AppLogic.logCustomAction(
        _state,
        action: '${staff.displayName} logged out',
        kind: HistoryKind.auth,
        actionType: HistoryActionType.logout,
        actor: staff,
      );
    }
    setState(() {
      _activeStaff = null;
      _selectedIndex = 0;
    });
    _appNotifier.setActiveStaffId(null);
    AppLogic.setCurrentStaff(null);
    _persistState();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Signed out')));
    _firebaseAuth?.signOut();
    _switchBar(BackendConfig.defaultBarId, clearActiveStaff: true);
  }

  void _showManagementWarning(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Manager or admin permissions required')),
    );
  }

  void _openHistory(BuildContext ctx) {
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  void _openStaffManagement(BuildContext ctx) {
    if (!_canAccessStaffManagement) {
      _showStaffAccessWarning(ctx);
      return;
    }
    Navigator.of(
      ctx,
    ).push(MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
  }

  void _showStaffAccessWarning(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text(
          'Staff management is available to managers, owners or admins',
        ),
      ),
    );
  }

  void _onManualSync(BuildContext ctx) {
    final messenger = ScaffoldMessenger.of(ctx);
    if (!_firebaseAvailable) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cloud sync available only online')),
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

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeStaff == null) {
      return LoginScreen(
        onLogin: _handleLogin,
        busy: _authBusy,
        errorMessage: _authError,
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
    if (_activeStaff == null) return const [];

    return [
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
        onPressed:
            _activeStaff == null ||
                !_appNotifier.canUndoForRole(_activeStaff!.role)
            ? null
            : () => _onUndo(ctx),
      ),
      IconButton(
        tooltip: 'History',
        icon: const Icon(Icons.history),
        onPressed: () => _openHistory(ctx),
      ),
      if (_canAccessStaffManagement)
        IconButton(
          tooltip: 'Staff accounts',
          icon: const Icon(Icons.group),
          onPressed: () => _openStaffManagement(ctx),
        ),
      IconButton(
        tooltip: 'Logout',
        icon: const Icon(Icons.logout),
        onPressed: () => _logout(ctx),
      ),
    ];
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
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
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
          return LoadingOverlay(
            isLoading: _loading || _syncingCloud,
            message: _loading ? 'Loading data...' : 'Syncing from cloud...',
            child: content,
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
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.local_bar),
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
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
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
