import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../models/task.dart';
import 'add_task_screen.dart';
import 'settings_screen.dart';
import '../services/export_service.dart';   // ← New import for export

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<TaskProvider>(context, listen: false).loadTasks());
  }

  bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final tasks = provider.tasks;

    final todayTasks = tasks.where((t) => isToday(t.dueDate) && !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();
    final repeatedTasks = tasks.where((t) => t.repeat != "none").toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Task Manager"),
          centerTitle: true,
          actions: [
            // Theme Toggle (unchanged)
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return IconButton(
                  icon: Icon(
                    themeProvider.themeMode == ThemeMode.dark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                );
              },
            ),
            // Settings Button (unchanged)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            // NEW: Export Button
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () async {
                if (provider.tasks.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No tasks to export")),
                  );
                  return;
                }

                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        title: Text(
                          "Export Tasks",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.table_chart, color: Colors.green),
                        title: const Text("Export to CSV"),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await ExportService.exportToCSV(provider.tasks);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("CSV exported successfully")),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Export failed: $e")),
                              );
                            }
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: const Text("Export to PDF"),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await ExportService.exportToPDF(provider.tasks);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("PDF exported successfully")),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Export failed: $e")),
                              );
                            }
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.email, color: Colors.blue),
                        title: const Text("Export & Email"),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await ExportService.exportAndEmail(provider.tasks);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Opening email...")),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Export failed: $e")),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Today"),
              Tab(text: "Completed"),
              Tab(text: "Repeated"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            buildTaskList(todayTasks, provider),
            buildTaskList(completedTasks, provider),
            buildTaskList(repeatedTasks, provider),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTaskScreen()),
            ).then((_) => provider.loadTasks());
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // buildTaskList remains EXACTLY the same as your previous code
  Widget buildTaskList(List<Task> tasks, TaskProvider provider) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          "No tasks yet 💤",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      onChanged: (val) {
                        if (val != null) {
                          provider.toggleComplete(task.id!, val);
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? Colors.grey : null,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddTaskScreen(task: task),
                              ),
                            ).then((_) => provider.loadTasks());
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Delete Task?"),
                                content: const Text("This action cannot be undone."),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Delete",
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && task.id != null) {
                              await provider.deleteTask(task.id!);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Task deleted")),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (task.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Text(
                      task.description,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(
                    "Due: ${task.dueDate.toString().split(' ')[0]}  ${task.time}",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 16),

                if (task.subTasks.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text("Progress",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                        "${(task.progress * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: task.progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.progress > 0.7
                            ? Colors.green
                            : task.progress > 0.4
                            ? Colors.orange
                            : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${task.subTasks.where((s) => s.isCompleted).length}/${task.subTasks.length} subtasks done",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}