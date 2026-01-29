class Task {
  int id;
  String title;
  bool done;
  DateTime? deadline;
  String? category;

  Task({
    int? id,
    required this.title, 
    this.done = false,
    this.deadline,
    this.category
  }) : id = id ?? (DateTime.now().millisecondsSinceEpoch % 2147483647); // Generate ID (fits in 32-bit int)

  // Convert ke Map untuk simpan di SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title, 
      'done': done,
      'deadline': deadline?.toIso8601String(),
      'category': category
    };
  }

  // Buat Task dari Map ke Task
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int?,
      title: json['title'] as String,
      done: json['done'] as bool? ?? false,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
      category: json['category'] as String?,
    );
  }
}
