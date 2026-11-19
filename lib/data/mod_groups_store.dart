import 'dart:convert';
import 'dart:io';

class ModGroup {
  const ModGroup({required this.id, required this.name, this.createdAt = 0});

  final String id;
  final String name;
  final int createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt,
  };

  factory ModGroup.fromJson(Map<String, dynamic> json) => ModGroup(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    createdAt: json['createdAt'] is num
        ? (json['createdAt'] as num).toInt()
        : 0,
  );
}

class ModGroupsState {
  const ModGroupsState({this.groups = const [], this.assignments = const {}});

  final List<ModGroup> groups;

  /// `loaderId|pkgId` -> group id
  final Map<String, String> assignments;

  static String keyOf(String loaderId, String pkgId) => '$loaderId|$pkgId';

  String? groupIdOf(String loaderId, String pkgId) {
    final id = assignments[keyOf(loaderId, pkgId)];
    if (id == null || !groups.any((g) => g.id == id)) return null;
    return id;
  }

  ModGroupsState copyWith({
    List<ModGroup>? groups,
    Map<String, String>? assignments,
  }) => ModGroupsState(
    groups: groups ?? this.groups,
    assignments: assignments ?? this.assignments,
  );

  Map<String, dynamic> toJson() => {
    'groups': [for (final group in groups) group.toJson()],
    'assignments': assignments,
  };

  factory ModGroupsState.fromJson(Map<String, dynamic> json) {
    final groups = <ModGroup>[];
    final rawGroups = json['groups'];
    if (rawGroups is List) {
      for (final entry in rawGroups) {
        if (entry is Map) {
          groups.add(ModGroup.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    final assignments = <String, String>{};
    final rawAssignments = json['assignments'];
    if (rawAssignments is Map) {
      rawAssignments.forEach((key, value) {
        if (value != null) assignments[key.toString()] = value.toString();
      });
    }
    return ModGroupsState(groups: groups, assignments: assignments);
  }
}

/// Per-instance manual mod groups. Stored next to the instance data so it can
/// be exported/imported together with the instance.
class ModGroupsStore {
  ModGroupsStore(this.instanceDir);

  final Directory instanceDir;

  File get file => File('${instanceDir.path}/mod_groups.json');

  Future<ModGroupsState> load() async {
    try {
      if (!await file.exists()) return const ModGroupsState();
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map) {
        return ModGroupsState.fromJson(raw.cast<String, dynamic>());
      }
    } catch (_) {}
    return const ModGroupsState();
  }

  Future<void> save(ModGroupsState state) async {
    const encoder = JsonEncoder.withIndent('  ');
    await file.parent.create(recursive: true);
    await file.writeAsString(encoder.convert(state.toJson()), flush: true);
  }
}
