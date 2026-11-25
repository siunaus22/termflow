import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/semester_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/sync/realtime_listener.dart';
import '../../data/sync/sync_engine.dart';

// ============================================================================
// 基础依赖 Providers（在 main.dart 中通过 ProviderScope.overrides 注入）
// ============================================================================

final appConfigStoreProvider = Provider<AppConfigStore>((ref) {
  throw UnimplementedError('AppConfigStore must be overridden in main.dart');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ============================================================================
// 主题状态
// ============================================================================

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._store) : super(_parse(_store.themeMode));

  final AppConfigStore _store;

  static ThemeMode _parse(String v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _store.setThemeMode(raw);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(appConfigStoreProvider));
});

class ThemeSeedNotifier extends StateNotifier<GoogleThemeSeed> {
  ThemeSeedNotifier(this._store)
      : super(GoogleThemeSeed.fromKey(_store.themeSeed));

  final AppConfigStore _store;

  Future<void> setSeed(GoogleThemeSeed seed) async {
    state = seed;
    await _store.setThemeSeed(seed.key);
  }
}

final themeSeedProvider =
    StateNotifierProvider<ThemeSeedNotifier, GoogleThemeSeed>((ref) {
  return ThemeSeedNotifier(ref.watch(appConfigStoreProvider));
});

/// 动态流体背景无障碍开关
class AmbientMotionNotifier extends StateNotifier<bool> {
  AmbientMotionNotifier(this._store) : super(_store.ambientMotionEnabled);

  final AppConfigStore _store;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _store.setAmbientMotionEnabled(enabled);
  }
}

final ambientMotionProvider =
    StateNotifierProvider<AmbientMotionNotifier, bool>((ref) {
  return AmbientMotionNotifier(ref.watch(appConfigStoreProvider));
});

/// Gemini 背景活跃联动状态：当聚焦主输入栏、打开新建弹窗或正在云端同步时平滑唤醒光晕
final geminiFocusActiveProvider = StateProvider<bool>((ref) => false);
final geminiFocusPointProvider =
    StateProvider<Offset>((ref) => const Offset(0.5, 0.30));

final geminiActivityProvider = Provider<bool>((ref) {
  final inputActive = ref.watch(geminiFocusActiveProvider);
  final syncPhase = ref.watch(syncControllerProvider).phase;
  return inputActive || syncPhase == SyncUiPhase.syncing;
});

// ============================================================================
// Supabase 连接与认证管理器（支持在设置页动态填写/更换 URL 与 Anon Key）
// ============================================================================

class SupabaseManagerState {
  const SupabaseManagerState({
    this.isInitialized = false,
    this.user,
    this.error,
  });

  final bool isInitialized;
  final User? user;
  final String? error;

  bool get isLoggedIn => isInitialized && user != null;
}

class SupabaseManager extends StateNotifier<SupabaseManagerState> {
  SupabaseManager(this._configStore) : super(const SupabaseManagerState());

  final AppConfigStore _configStore;
  StreamSubscription<AuthState>? _authSub;
  bool _sdkInitialized = false;

  SupabaseClient? get client =>
      _sdkInitialized ? Supabase.instance.client : null;

  /// 启动时或设置页保存配置后初始化/重连 Supabase
  Future<bool> initializeFromStore() async {
    if (!_configStore.hasSupabaseConfig) {
      state = const SupabaseManagerState(isInitialized: false);
      return false;
    }

    return connect(
      url: _configStore.supabaseUrl,
      anonKey: _configStore.supabaseAnonKey,
    );
  }

  Future<bool> connect({required String url, required String anonKey}) async {
    try {
      await _authSub?.cancel();
      _authSub = null;

      if (_sdkInitialized) {
        await Supabase.instance.dispose();
        _sdkInitialized = false;
      }

      await Supabase.initialize(
        url: url.trim(),
        anonKey: anonKey.trim(),
      );
      _sdkInitialized = true;

      final currentClient = Supabase.instance.client;
      state = SupabaseManagerState(
        isInitialized: true,
        user: currentClient.auth.currentUser,
      );

      _authSub = currentClient.auth.onAuthStateChange.listen((authState) {
        state = SupabaseManagerState(
          isInitialized: true,
          user: authState.session?.user,
        );
      });
      return true;
    } catch (e) {
      _sdkInitialized = false;
      state = SupabaseManagerState(
        isInitialized: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<String?> signIn(String email, String password) async {
    final c = client;
    if (c == null) return '请先配置并连接 Supabase 服务';
    try {
      await c.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(String email, String password) async {
    final c = client;
    if (c == null) return '请先配置并连接 Supabase 服务';
    try {
      await c.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    final c = client;
    if (c != null) {
      await c.auth.signOut();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final supabaseManagerProvider =
    StateNotifierProvider<SupabaseManager, SupabaseManagerState>((ref) {
  final store = ref.watch(appConfigStoreProvider);
  final mgr = SupabaseManager(store);
  mgr.initializeFromStore();
  return mgr;
});

// ============================================================================
// 数据仓库 Providers
// ============================================================================

final semesterRepositoryProvider = Provider<SemesterRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SemesterRepository(
    db,
    () => ref.read(supabaseManagerProvider).user?.id,
  );
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoalRepository(
    db,
    () => ref.read(supabaseManagerProvider).user?.id,
  );
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TagRepository(
    db,
    () => ref.read(supabaseManagerProvider).user?.id,
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);
  final tagRepo = ref.watch(tagRepositoryProvider);
  return TaskRepository(
    db,
    goalRepo,
    tagRepo,
    () => ref.read(supabaseManagerProvider).user?.id,
  );
});

// ============================================================================
// 同步引擎与后台自动同步控制器（手动同步 + 网络恢复自动同步 + Realtime 监听）
// ============================================================================

enum SyncUiPhase { offline, idle, syncing, success, error }

class SyncUiState {
  const SyncUiState({
    this.phase = SyncUiPhase.offline,
    this.lastSyncedAt,
    this.lastSummary,
    this.errorMessage,
  });

  final SyncUiPhase phase;
  final DateTime? lastSyncedAt;
  final String? lastSummary;
  final String? errorMessage;
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: ref.watch(appDatabaseProvider),
    goalRepository: ref.watch(goalRepositoryProvider),
    getClient: () => ref.read(supabaseManagerProvider.notifier).client,
  );
});

class SyncController extends StateNotifier<SyncUiState> {
  SyncController(this._ref) : super(const SyncUiState()) {
    _realtime = RealtimeSyncListener(
      onRemoteChange: () async {
        if (_ref.read(appConfigStoreProvider).autoSyncEnabled) {
          await syncNow(silent: true);
        }
      },
    );

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (hasNet &&
          _ref.read(appConfigStoreProvider).autoSyncEnabled &&
          _ref.read(supabaseManagerProvider).isLoggedIn) {
        syncNow(silent: true);
      }
    });

    // 监听登录态变化：登录后立即拉取 + 开启 Realtime 监听；登出时停止监听
    _ref.listen<SupabaseManagerState>(
      supabaseManagerProvider,
      (prev, next) {
        final client = _ref.read(supabaseManagerProvider.notifier).client;
        if (next.isLoggedIn && client != null) {
          _realtime.start(client, next.user!.id);
          if (_ref.read(appConfigStoreProvider).autoSyncEnabled) {
            syncNow(silent: true);
          }
        } else {
          _realtime.stop(client);
          state = const SyncUiState(phase: SyncUiPhase.offline);
        }
      },
      fireImmediately: true,
    );

    // 定时后台自动同步（每 3 分钟兜底一次，推送本地 pending 变更）
    _periodicTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (_ref.read(appConfigStoreProvider).autoSyncEnabled &&
          _ref.read(supabaseManagerProvider).isLoggedIn) {
        syncNow(silent: true);
      }
    });
  }

  final Ref _ref;
  late final RealtimeSyncListener _realtime;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;

  Future<SyncResult> syncNow({bool silent = false}) async {
    final authState = _ref.read(supabaseManagerProvider);
    if (!authState.isLoggedIn) {
      if (!silent) {
        state = const SyncUiState(
          phase: SyncUiPhase.offline,
          errorMessage: '当前为离线模式，请在设置中配置并登录 Supabase',
        );
      }
      return const SyncResult(success: false, errorMessage: '未登录云端账号');
    }

    state = SyncUiState(
      phase: SyncUiPhase.syncing,
      lastSyncedAt: state.lastSyncedAt,
      lastSummary: '正在同步...',
    );

    final result = await _ref.read(syncEngineProvider).syncAll();
    if (result.success) {
      state = SyncUiState(
        phase: SyncUiPhase.success,
        lastSyncedAt: result.syncedAt ?? DateTime.now().toUtc(),
        lastSummary: '拉取 ${result.pulledCount} 条 · 推送 ${result.pushedCount} 条',
      );
    } else {
      state = SyncUiState(
        phase: SyncUiPhase.error,
        lastSyncedAt: state.lastSyncedAt,
        errorMessage: result.errorMessage,
      );
    }
    return result;
  }

  Future<void> resetCursorsAndResync() async {
    await _ref.read(syncEngineProvider).resetSyncCursors();
    await syncNow();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    _realtime.dispose();
    super.dispose();
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncUiState>((ref) {
  return SyncController(ref);
});

final pendingChangeCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).watchPendingChangeCount();
});

// ============================================================================
// 响应式业务数据 Streams & UI 导航状态
// ============================================================================

final activeNavProvider = StateProvider<NavSection>((ref) => NavSection.daily);
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);
final selectedTaskIdProvider = StateProvider<String?>((ref) => null);

final selectedDateProvider =
    StateProvider<DateTime>((ref) => TermDateUtils.dateOnly(DateTime.now()));
final selectedWeekStartProvider = StateProvider<DateTime>(
  (ref) => TermDateUtils.startOfWeek(DateTime.now()),
);
final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month, 1),
);

final semestersStreamProvider = StreamProvider<List<SemesterRow>>((ref) {
  return ref.watch(semesterRepositoryProvider).watchAll();
});

final activeSemesterProvider = StreamProvider<SemesterRow?>((ref) {
  return ref.watch(semesterRepositoryProvider).watchActive();
});

final allGoalsStreamProvider = StreamProvider<List<GoalRow>>((ref) {
  return ref.watch(goalRepositoryProvider).watchAllActiveGoals();
});

final tagsStreamProvider = StreamProvider<List<TagRow>>((ref) {
  return ref.watch(tagRepositoryProvider).watchAllTags();
});

final taskTagsMapProvider = StreamProvider<Map<String, List<TagRow>>>((ref) {
  return ref.watch(tagRepositoryProvider).watchTaskTagsMap();
});

final dailyTasksStreamProvider = StreamProvider<List<TaskRow>>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref
      .watch(taskRepositoryProvider)
      .watchTasksForDate(TermDateUtils.formatIsoDate(date));
});

final overdueTasksStreamProvider = StreamProvider<List<TaskRow>>((ref) {
  return ref
      .watch(taskRepositoryProvider)
      .watchOverdueUnfinishedTasks(TermDateUtils.todayIso());
});

final weeklyTasksStreamProvider = StreamProvider<List<TaskRow>>((ref) {
  final weekStart = ref.watch(selectedWeekStartProvider);
  return ref
      .watch(taskRepositoryProvider)
      .watchTasksForWeek(TermDateUtils.formatIsoDate(weekStart));
});

final weeklyGoalsStreamProvider = StreamProvider<List<GoalRow>>((ref) {
  final weekStart = ref.watch(selectedWeekStartProvider);
  return ref
      .watch(goalRepositoryProvider)
      .watchWeeklyGoals(weekStartDate: TermDateUtils.formatIsoDate(weekStart));
});

final monthlyTasksStreamProvider = StreamProvider<List<TaskRow>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(taskRepositoryProvider)
      .watchTasksForMonth(month.year, month.month);
});

final monthlyGoalsStreamProvider = StreamProvider<List<GoalRow>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(goalRepositoryProvider)
      .watchMonthlyGoals(year: month.year, month: month.month);
});

final semesterGoalsStreamProvider = StreamProvider<List<GoalRow>>((ref) {
  final activeSemester = ref.watch(activeSemesterProvider).valueOrNull;
  return ref
      .watch(goalRepositoryProvider)
      .watchSemesterGoals(activeSemester?.id);
});
