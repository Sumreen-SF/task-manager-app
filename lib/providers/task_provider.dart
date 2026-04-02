import 'package:flutter/material.dart';
import '../models/task.dart';
import '../db/database_helper.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    _tasks = await DatabaseHelper.instance.getTasks();
    await _resetRepeatingTasks();

    _isLoading = false;
    notifyListeners();
  }

  // Reset repeating tasks daily (after midnight) — only resets, never duplicates
  Future<void> _resetRepeatingTasks() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool hasChanges = false;

    for (var task in List<Task>.from(_tasks)) {
      if (task.repeat == "none" || !task.isCompleted) continue;

      final taskDay = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );

      bool shouldReset = false;
      DateTime newDueDate = task.dueDate;

      if (task.repeat == "daily") {
        // Reset if the task's due date is before today
        if (taskDay.isBefore(today)) {
          newDueDate = DateTime(
            now.year, now.month, now.day,
            task.dueDate.hour, task.dueDate.minute,
          );
          shouldReset = true;
        }
      } else if (task.repeat == "weekly" && task.repeatDays.isNotEmpty) {
        if (taskDay.isBefore(today)) {
          final todayName = _getDayName(now.weekday);
          if (task.repeatDays.contains(todayName)) {
            newDueDate = DateTime(
              now.year, now.month, now.day,
              task.dueDate.hour, task.dueDate.minute,
            );
            shouldReset = true;
          }
        }
      }

      if (shouldReset) {
        final resetTask = Task(
          id: task.id,
          title: task.title,
          description: task.description,
          dueDate: newDueDate,
          time: task.time,
          repeat: task.repeat,
          repeatDays: task.repeatDays,
          isCompleted: false,
          progress: 0.0,
          subTasks: task.subTasks
              .map((s) => SubTask(
            id: s.id,
            taskId: s.taskId,
            title: s.title,
            isCompleted: false,
          ))
              .toList(),
        );

        await DatabaseHelper.instance.updateTask(resetTask);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      _tasks = await DatabaseHelper.instance.getTasks();
    }
  }

  String _getDayName(int weekday) {
    const days = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[weekday];
  }

  Future<void> addTask(Task task) async {
    await DatabaseHelper.instance.insertTask(task);
    _tasks = await DatabaseHelper.instance.getTasks();
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    if (task.id == null) return;
    await DatabaseHelper.instance.updateTask(task);
    _tasks = await DatabaseHelper.instance.getTasks();
    notifyListeners();
  }

  Future<void> deleteTask(int id) async {
    await DatabaseHelper.instance.deleteTask(id);
    _tasks = await DatabaseHelper.instance.getTasks();
    notifyListeners();
  }

  Future<void> toggleComplete(int id, bool isCompleted) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];

    // Optimistically update UI immediately
    _tasks[taskIndex] = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      time: task.time,
      repeat: task.repeat,
      repeatDays: task.repeatDays,
      isCompleted: isCompleted,
      progress: isCompleted ? 1.0 : task.progress,
      subTasks: task.subTasks,
    );
    notifyListeners();

    // Persist to DB
    await DatabaseHelper.instance.updateTask(_tasks[taskIndex]);

    // For repeating tasks: update due date to next occurrence (don't create duplicate)
    if (isCompleted && task.repeat != "none") {
      DateTime nextDue = task.dueDate;

      if (task.repeat == "daily") {
        nextDue = task.dueDate.add(const Duration(days: 1));
      } else if (task.repeat == "weekly" && task.repeatDays.isNotEmpty) {
        int daysToAdd = 1;
        while (daysToAdd < 8) {
          final nextDay = task.dueDate.add(Duration(days: daysToAdd));
          final dayName = _getDayName(nextDay.weekday);
          if (task.repeatDays.contains(dayName)) {
            nextDue = DateTime(
              nextDay.year, nextDay.month, nextDay.day,
              task.dueDate.hour, task.dueDate.minute,
            );
            break;
          }
          daysToAdd++;
        }
      }

      // Update the same task's due date (no new task created)
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        dueDate: nextDue,
        time: task.time,
        repeat: task.repeat,
        repeatDays: task.repeatDays,
        isCompleted: true, // stays completed until midnight reset
        progress: 1.0,
        subTasks: task.subTasks
            .map((s) => SubTask(
          id: s.id,
          taskId: s.taskId,
          title: s.title,
          isCompleted: false,
        ))
            .toList(),
      );

      await DatabaseHelper.instance.updateTask(updatedTask);
      _tasks = await DatabaseHelper.instance.getTasks();
      notifyListeners();
    }
  }

  Future<void> toggleSubTask(int taskId, int subTaskIndex, bool isCompleted) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];
    if (subTaskIndex < 0 || subTaskIndex >= task.subTasks.length) return;

    final updatedSubTasks = List<SubTask>.from(task.subTasks);
    updatedSubTasks[subTaskIndex] = SubTask(
      id: task.subTasks[subTaskIndex].id,
      taskId: taskId,
      title: task.subTasks[subTaskIndex].title,
      isCompleted: isCompleted,
    );

    final double progress =
        updatedSubTasks.where((s) => s.isCompleted).length /
            updatedSubTasks.length;

    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      time: task.time,
      repeat: task.repeat,
      repeatDays: task.repeatDays,
      isCompleted: task.isCompleted,
      progress: progress,
      subTasks: updatedSubTasks,
    );

    // Optimistic update
    _tasks[taskIndex] = updatedTask;
    notifyListeners();

    await DatabaseHelper.instance.updateTask(updatedTask);
  }
}