import 'package:saccm/core/local_data_source/app_menu_local_data_source.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';

class MenuService {
  MenuService({AppMenuLocalDataSource? localDataSource})
      : _localDataSource = localDataSource ?? AppMenuLocalDataSource();

  final AppMenuLocalDataSource _localDataSource;

  Future<NavMenuSnapshot> loadMenuSnapshot() {
    return _localDataSource.loadSnapshot();
  }

  List<int> allowedNavIndexes({
    required NavMenuSnapshot snapshot,
    required SimpleAuthProvider auth,
  }) {
    final keys = snapshot.slotsByNavIndex.keys.toList()..sort();
    final out = <int>[];
    for (final key in keys) {
      final slot = snapshot.slotsByNavIndex[key];
      if (slot == null) continue;
      if (auth.can(slot.requiredPermission)) out.add(key);
    }
    return out;
  }

  List<NavMenuSectionSpec> visibleSections({
    required NavMenuSnapshot snapshot,
    required List<int> allowedIndexes,
  }) {
    final allowed = allowedIndexes.toSet();
    return snapshot.sections
        .map(
          (section) => NavMenuSectionSpec(
            title: section.title,
            navIndexes: section.navIndexes
                .where((index) => allowed.contains(index))
                .toList(),
          ),
        )
        .where((section) => section.navIndexes.isNotEmpty)
        .toList();
  }
}
