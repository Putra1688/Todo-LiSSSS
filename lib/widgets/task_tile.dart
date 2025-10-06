import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String? formattedDeadline;
    if (task.deadline != null) {
      formattedDeadline = DateFormat('dd MMM yyyy, HH:mm').format(task.deadline!.toLocal());
    }

    final overdue = task.deadline != null && task.deadline!.isBefore(DateTime.now()) && !task.done;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: task.done
              ? [Colors.green.shade100, Colors.green.shade50]
              : [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Checkbox(
          value: task.done,
          onChanged: onChanged,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: task.done ? Colors.grey : Colors.black87,
            decoration: task.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (formattedDeadline != null)
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14, color: overdue ? Colors.red : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formattedDeadline,
                    style: TextStyle(
                      color: overdue ? Colors.red : Colors.grey,
                      fontSize: 13,
                      fontWeight: overdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            if (task.category != null) const SizedBox(height: 6),
            if (task.category != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder, size: 14, color: Colors.deepPurple),
                    const SizedBox(width: 4),
                    Text(
                      task.category!,
                      style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
