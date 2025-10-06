import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskService {
  static const String _tasksKey = 'tasks';
  static const String _categoriesKey = 'categories';
// yang dipake nanti saveTask dan loadTask

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString( _tasksKey, jsonString);
  }

  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_tasksKey);
    if (jsonString == null) return [];
    final decoded = jsonDecode(jsonString) as List;
    return decoded.map((e) => Task.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoriesKey, categories);
  }

  Future<List<String>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_categoriesKey) ?? [];
  }
}
