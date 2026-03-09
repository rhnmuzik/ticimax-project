// lib/models/workflow.dart
// Workflow modeli - birden fazla scripti sırayla çalıştırma

class Workflow {
  final String id;
  final String name;
  final String description;
  final List<String> scripts;
  final bool enabled;
  final String? schedule; // "09:00", "14:30" gibi
  final DateTime? lastRun;
  final String? lastStatus; // "success", "failed", "running"

  Workflow({
    required this.id,
    required this.name,
    required this.description,
    required this.scripts,
    this.enabled = true,
    this.schedule,
    this.lastRun,
    this.lastStatus,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'scripts': scripts,
    'enabled': enabled,
    'schedule': schedule,
    'lastRun': lastRun?.toIso8601String(),
    'lastStatus': lastStatus,
  };

  factory Workflow.fromJson(Map<String, dynamic> json) => Workflow(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    scripts: (json['scripts'] as List?)?.cast<String>() ?? [],
    enabled: json['enabled'] as bool? ?? true,
    schedule: json['schedule'] as String?,
    lastRun: json['lastRun'] != null
        ? DateTime.parse(json['lastRun'] as String)
        : null,
    lastStatus: json['lastStatus'] as String?,
  );

  Workflow copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? scripts,
    bool? enabled,
    String? schedule,
    DateTime? lastRun,
    String? lastStatus,
  }) => Workflow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    scripts: scripts ?? this.scripts,
    enabled: enabled ?? this.enabled,
    schedule: schedule ?? this.schedule,
    lastRun: lastRun ?? this.lastRun,
    lastStatus: lastStatus ?? this.lastStatus,
  );
}
