import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;
  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String repeat = "none";
  List<String> selectedRepeatDays = [];

  List<SubTask> subTasks = [];

  static const List<String> _weekDays = [
    "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descController.text = widget.task!.description;
      selectedDate = widget.task!.dueDate;
      repeat = widget.task!.repeat;
      selectedRepeatDays = List<String>.from(widget.task!.repeatDays);
      subTasks = List.from(widget.task!.subTasks);

      if (widget.task!.time.isNotEmpty) {
        final parts = widget.task!.time.split(':');
        if (parts.length >= 2) {
          selectedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  void _toggleRepeatDay(String day) {
    setState(() {
      if (selectedRepeatDays.contains(day)) {
        selectedRepeatDays.remove(day);
      } else {
        selectedRepeatDays.add(day);
      }
    });
  }

  void _addSubTask() async {
    final subTaskTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text("Add Subtask"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Subtask title"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );

    if (subTaskTitle != null && subTaskTitle.isNotEmpty) {
      setState(() => subTasks.add(SubTask(title: subTaskTitle)));
    }
  }

  void _toggleSubTask(int index, bool? value) {
    if (value == null) return;
    setState(() {
      subTasks[index] = SubTask(
        id: subTasks[index].id,
        taskId: subTasks[index].taskId,
        title: subTasks[index].title,
        isCompleted: value,
      );
    });
  }

  Future<void> saveTask() async {
    if (_titleController.text.trim().isEmpty || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and select a due date')),
      );
      return;
    }

    // Validate: weekly repeat requires at least one day selected
    if (repeat == "weekly" && selectedRepeatDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day for weekly repeat')),
      );
      return;
    }

    final time = selectedTime ?? TimeOfDay.now();
    final timeString =
        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

    final double progress = subTasks.isEmpty
        ? (widget.task?.isCompleted ?? false ? 1.0 : 0.0)
        : subTasks.where((s) => s.isCompleted).length / subTasks.length;

    final task = Task(
      id: widget.task?.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      dueDate: selectedDate!,
      time: timeString,
      repeat: repeat,
      repeatDays: repeat == "weekly" ? selectedRepeatDays : [],
      isCompleted: widget.task?.isCompleted ?? false,
      subTasks: subTasks,
      progress: progress,
    );

    final provider = Provider.of<TaskProvider>(context, listen: false);

    try {
      if (widget.task == null) {
        await provider.addTask(task);

        // Get saved notification sound
        final prefs = await SharedPreferences.getInstance();
        final savedSound = prefs.getString('notification_sound');
        final soundToUse =
        (savedSound == null || savedSound == "default") ? null : savedSound;

        final scheduleDateTime = DateTime.now().add(const Duration(minutes: 1));

        await NotificationService.scheduleNotification(
          id: DateTime.now().millisecondsSinceEpoch % 1000000,
          title: task.title,
          body: "Reminder: ${task.title} is due soon!",
          dateTime: scheduleDateTime,
          sound: soundToUse,
        );
      } else {
        await provider.updateTask(task);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.task == null ? 'Task added successfully!' : 'Task updated!',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? "Add New Task" : "Edit Task"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ──────────────────────────────────────────────
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Task Title *",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Description ────────────────────────────────────────
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ── Due Date ───────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  selectedDate == null
                      ? "Select Due Date *"
                      : "Due Date: ${selectedDate!.toString().split(' ')[0]}",
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // ── Time ───────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: pickTime,
                icon: const Icon(Icons.access_time),
                label: Text(
                  selectedTime == null
                      ? "Select Time"
                      : "Time: ${selectedTime!.format(context)}",
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // ── Repeat Dropdown ────────────────────────────────────
              DropdownButtonFormField<String>(
                value: repeat,
                decoration: const InputDecoration(
                  labelText: "Repeat",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "none", child: Text("No Repeat")),
                  DropdownMenuItem(value: "daily", child: Text("Daily")),
                  DropdownMenuItem(value: "weekly", child: Text("Weekly")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      repeat = val;
                      // Clear day selection when switching away from weekly
                      if (val != "weekly") selectedRepeatDays.clear();
                    });
                  }
                },
              ),

              // ── Weekly Day Selector (shown only when repeat == "weekly") ──
              if (repeat == "weekly") ...[
                const SizedBox(height: 16),
                const Text(
                  "Repeat on days",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _weekDays.map((day) {
                    final isSelected = selectedRepeatDays.contains(day);
                    return FilterChip(
                      label: Text(day),
                      selected: isSelected,
                      onSelected: (_) => _toggleRepeatDay(day),
                      selectedColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                if (selectedRepeatDays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      "Select at least one day",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // ── Subtasks ───────────────────────────────────────────
              const Text(
                "Subtasks",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (subTasks.isNotEmpty)
                Card(
                  child: Column(
                    children: subTasks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final sub = entry.value;
                      return CheckboxListTile(
                        value: sub.isCompleted,
                        title: Text(sub.title),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) => _toggleSubTask(index, val),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addSubTask,
                icon: const Icon(Icons.add),
                label: const Text("Add Subtask"),
              ),

              const SizedBox(height: 32),

              // ── Save Button ────────────────────────────────────────
              ElevatedButton(
                onPressed: saveTask,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  widget.task == null ? "Add Task" : "Update Task",
                  style: const TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}