// lib/pages/todo_page.dart
import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '../models/task.dart';
import '../services/task_services.dart';
import '../services/notification_service.dart';
import '../widgets/task_tile.dart';
import 'dart:ui';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TaskService _taskService = TaskService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _controller = TextEditingController();
  final PanelController _panelController = PanelController();

  List<Task> _todoList = [];
  List<String> _categories = []; // custom categories only
  String? _selectedCategory; // null = show all

  static const int maxCustomCategories = 3;
  static const String noneCategoryLabel = 'Tanpa Kategori';

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadAll();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
    await _notificationService.requestPermissions();
  }

  Future<void> _loadAll() async {
    _todoList = await _taskService.loadTasks();
    _categories = await _taskService.loadCategories();
    setState(() {});
  }

  // SAVE helpers
  Future<void> _saveTasks() async {
    await _taskService.saveTasks(_todoList);
  }

  Future<void> _saveCategories() async {
    await _taskService.saveCategories(_categories);
  }

  // TASK CRUD (by data object — safe when filtering)
  void _addTask(String title, DateTime? deadline, String? category) {
    if (title.trim().isEmpty) return;
    final t = Task(title: title.trim(), deadline: deadline, category: category);
    setState(() => _todoList.add(t));
    _saveTasks();
    _notificationService.scheduleTaskNotifications(t);
    _controller.clear();
    // when adding a task and panel is down, open a bit so user sees update
    _panelController.open();
  }

  void _toggleTaskByTask(Task task, bool? value) {
    final idx = _todoList.indexOf(task);
    if (idx != -1) {
      setState(() => _todoList[idx].done = value ?? false);
      _saveTasks();
      if (_todoList[idx].done) {
        _notificationService.cancelTaskNotifications(_todoList[idx]);
      } else {
        _notificationService.scheduleTaskNotifications(_todoList[idx]);
      }
    }
  }

  void _deleteTaskByTask(Task task) {
    final idx = _todoList.indexOf(task);
    if (idx != -1) {
      setState(() => _todoList.removeAt(idx));
      _saveTasks();
      _notificationService.cancelTaskNotifications(task);
    }
  }

  // CATEGORY management
  Future<void> _showAddCategoryDialog() async {
    if (_categories.length >= maxCustomCategories) {
      _showMessage(
        'Jumlah kategori sudah maksimal ($maxCustomCategories). Hapus kategori lain untuk menambahkan yang baru.',
      );
      return;
    }

    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kategori'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nama kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final name = controller.text.trim();
      if (name.isEmpty)
        return _showMessage('Nama kategori tidak boleh kosong.');
      if (_categories.contains(name))
        return _showMessage('Kategori sudah ada.');
      setState(() => _categories.add(name));
      await _saveCategories();
      _showMessage('Kategori "$name" ditambahkan.');
    }
  }

  Future<void> _confirmRemoveCategory(String category) async {
    if (category == noneCategoryLabel) {
      _showMessage('Kategori "$noneCategoryLabel" tidak dapat dihapus.');
      return;
    }

    final tasksInCat = _todoList
        .where((t) => (t.category ?? noneCategoryLabel) == category)
        .toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus kategori "$category"?'),
        content: tasksInCat.isEmpty
            ? Text('Kategori ini kosong. Yakin ingin menghapus?')
            : Text(
                'Semua task pada kategori "$category" akan dipindahkan ke "$noneCategoryLabel". Yakin hapus?',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // pindahkan tasks ke Tanpa Kategori
      if (tasksInCat.isNotEmpty) {
        for (var t in tasksInCat) {
          t.category = null; // berarti Tanpa Kategori
        }
        await _saveTasks();
      }
      // hapus kategori
      setState(() => _categories.remove(category));
      await _saveCategories();
      // jika filter aktif pada kategori ini, reset filter
      if (_selectedCategory == category) _selectedCategory = null;
      _showMessage('Kategori "$category" dihapus.');
    }
  }

  void _filterByCategory(String? category) {
    setState(() => _selectedCategory = category);
    // buka panel full agar user lihat hasil
    _panelController.open();
  }

  void _resetFilter() {
    setState(() => _selectedCategory = null);
    _showMessage('Filter dihapus. Menampilkan semua task.');
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ADD TASK DIALOG (pakai _categories dynamic)
  void _showAddTaskDialog() {
    DateTime? selectedDeadline;
    String? selectedCategory;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Nama task'),
                    ),
                    const SizedBox(height: 10),
                    // Deadline picker
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDeadline == null
                                ? 'Tanpa deadline'
                                : 'Deadline: ${selectedDeadline?.toLocal()}',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  selectedDeadline = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),
                        if (selectedDeadline != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setDialogState(() => selectedDeadline = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Category dropdown
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Pilih kategori (opsional)'),
                            value: selectedCategory,
                            items: [
                              // show null as "Tanpa Kategori" option
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(noneCategoryLabel),
                              ),
                              ..._categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                            ],
                            onChanged: (v) =>
                                setDialogState(() => selectedCategory = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // button add category
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _showAddCategoryDialog();
                          // reopen the Add Task dialog so user can pick new category
                          Future.delayed(
                            Duration.zero,
                            () => _showAddTaskDialog(),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah kategori baru'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _controller.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final cat = selectedCategory == noneCategoryLabel
                        ? null
                        : selectedCategory;
                    _addTask(_controller.text, selectedDeadline, cat);
                    Navigator.pop(context);
                  },
                  child: const Text('Tambah'),
                ),
                
              ],
            );
          },
        );
      },
    );
  }

  // Build dashboard (grid 3 kolom)
  // Widget _buildDashboard() {
  //   final displayCategories = [noneCategoryLabel, ..._categories];
  //   final canAddMore = _categories.length < maxCustomCategories;

  //   return SafeArea(
  //     child: Column(
  //       children: [
  //         const SizedBox(height: 12),
  //         const Text(
  //           'Dashboard',
  //           style: TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.white,
  //           ),
  //         ),
  //         const SizedBox(height: 12),
  //         Padding(
  //           padding: const EdgeInsets.symmetric(horizontal: 12),
  //           child: GridView.count(
  //             crossAxisCount: 4,
  //             shrinkWrap: true,
  //             physics: const NeverScrollableScrollPhysics(),
  //             crossAxisSpacing: 5,
  //             mainAxisSpacing: 5,
  //             childAspectRatio: 0.95,
  //             children: [
  //               ...displayCategories.map((cat) {
  //                 final count = _todoList
  //                     .where((t) => (t.category ?? noneCategoryLabel) == cat)
  //                     .length;
  //                 final isSelected = _selectedCategory == cat;
  //                 return GestureDetector(
  //                   onTap: () => _filterByCategory(
  //                     cat == noneCategoryLabel ? null : cat,
  //                   ),
  //                   onLongPress: () {
  //                     if (cat == noneCategoryLabel)
  //                       return _showMessage(
  //                         'Kategori "$noneCategoryLabel" tidak dapat dihapus.',
  //                       );
  //                     _confirmRemoveCategory(cat);
  //                   },
  //                   child: Container(
  //                     decoration: BoxDecoration(
  //                       gradient: LinearGradient(
  //                         colors: isSelected
  //                             ? [Colors.orange, Colors.deepOrange]
  //                             : [Colors.yellow[400]!, Colors.yellow[700]!],
  //                         begin: Alignment.topLeft,
  //                         end: Alignment.bottomRight,
  //                       ),
  //                       borderRadius: BorderRadius.circular(12),
  //                       boxShadow: [
  //                         BoxShadow(
  //                           color: Colors.black.withOpacity(0.08),
  //                           blurRadius: 6,
  //                           offset: const Offset(0, 2),
  //                         ),
  //                       ],
  //                     ),
  //                     child: Padding(
  //                       padding: const EdgeInsets.all(8.0),
  //                       child: Column(
  //                         mainAxisAlignment: MainAxisAlignment.center,
  //                         children: [
  //                           Text(
  //                             cat,
  //                             textAlign: TextAlign.center,
  //                             style: const TextStyle(
  //                               fontWeight: FontWeight.bold,
  //                               color: Colors.black,
  //                             ),
  //                           ),
  //                           const SizedBox(height: 8),
  //                           Text(
  //                             '$count Task',
  //                             style: const TextStyle(
  //                               fontSize: 12,
  //                               color: Colors.black,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                 );
  //               }).toList(),
  //               if (canAddMore)
  //                 GestureDetector(
  //                   onTap: _showAddCategoryDialog,
  //                   child: Card(
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                     child: Center(
  //                       child: Column(
  //                         mainAxisSize: MainAxisSize.min,
  //                         children: const [
  //                           Icon(Icons.add),
  //                           SizedBox(height: 6),
  //                           Text('Tambah'),
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //             ],
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         const Padding(
  //           padding: EdgeInsets.symmetric(horizontal: 12),
  //           child: Text(
  //             'Geser ke atas untuk melihat daftar tugas',
  //             style: TextStyle(fontSize: 12, color: Colors.white),
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //       ],
  //     ),
  //   );
  // }

  // Panel content: task list (filtered)
  Widget _buildPanel() {
    final filtered = _selectedCategory == null
        ? _todoList
        : _todoList
              .where(
                (t) => (t.category ?? noneCategoryLabel) == _selectedCategory,
              )
              .toList();

    if (filtered.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Tidak ada task', style: TextStyle(fontSize: 16)),
          ),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final task = filtered[index];
              return TaskTile(
                task: task,
                onChanged: (v) => _toggleTaskByTask(task, v),
                onDelete: () => _deleteTaskByTask(task),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  // ganti bagian build UI
@override
Widget build(BuildContext context) {
  final total = _todoList.length;
  final done = _todoList.where((t) => t.done).length;

  return Stack(
    children: [
      // Gradient background
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4A00E0),
              Color(0xFF8E2DE2),
              Color(0xFF3F51B5),
              Color(0xFF00BCD4),
            ],
          ),
        ),
      ),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Column(
            children: const [
              
              Text(
                "Todo - LiSSSS",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "To Do List Sangat Sederhana Simpel Sekali",
                style: TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
        body: SlidingUpPanel(
          controller: _panelController,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          minHeight: 380,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          
          panel: _buildPanel(),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Glassmorphism summary
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Total Task",
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                                Text("$total",
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Selesai",
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                                Text("$done",
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ]),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Dashboard
                _buildDashboard(),

                const SizedBox(height: 300),
              ],
            ),
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: Colors.transparent,
            elevation: 0,
            onPressed: _showAddTaskDialog,
            child: const Icon(Icons.add, size: 32, color: Colors.white),
          ),
        ),
      ),
    ],
  );
}

// --- ubah dashboard jadi lebih modern
Widget _buildDashboard() {
  final displayCategories = [noneCategoryLabel, ..._categories];
  final canAddMore = _categories.length < maxCustomCategories;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
       Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // Kiri: Icon + Teks Dashboard
    Row(
      children: const [
        Icon(Icons.dashboard, color: Colors.white),
        SizedBox(width: 8),
        Text(
          "Dashboard",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    ),

    // Kanan: Icon Reset Filter
    IconButton(
      tooltip: "Reset Filter",
      onPressed: _resetFilter,
      icon: const Icon(
        Icons.filter_alt_off,
        color: Colors.white,
      ),
    ),
  ],
),

        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: [
            ...displayCategories.map((cat) {
              final count = _todoList
                  .where((t) => (t.category ?? noneCategoryLabel) == cat)
                  .length;
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () =>
                    _filterByCategory(cat == noneCategoryLabel ? null : cat),
                onLongPress: () {
                  if (cat == noneCategoryLabel) {
                    return _showMessage(
                        'Kategori "$noneCategoryLabel" tidak dapat dihapus.');
                  }
                  _confirmRemoveCategory(cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [Colors.greenAccent.shade400, Colors.teal]
                          : [Colors.amber.shade300, Colors.orange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text("$count Task",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            if (canAddMore)
              GestureDetector(
                onTap: _showAddCategoryDialog,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: const Center(
                    child: Icon(Icons.add, size: 30, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

}
