class Task {
  String title;
  bool done;
  DateTime? deadline;
  String? category;

  Task({
    required this.title, 
    this.done = false,
    this.deadline,
    this.category
  });

  // Convert ke Map untuk simpan di SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'title': title, 
      'done': done,
      'deadline': deadline?.toIso8601String(),
      'category': category
    };
  }

  // Buat Task dari Map ke Task
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'] as String,
      done: json['done'] as bool? ?? false,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
      category: json['category'] as String?,
    );
  }
}
