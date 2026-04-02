class SubTask {
  int? id;
  int? taskId;
  String title;
  bool isCompleted;

  SubTask({
    this.id,
    this.taskId,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'],
      taskId: map['taskId'],
      title: map['title'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
}

class Task {
  int? id;
  String title;
  String description;
  DateTime dueDate;
  String time;
  bool isCompleted;
  String repeat;                    // "none", "daily", "weekly"
  List<String> repeatDays;          // e.g. ["Mon", "Wed", "Fri"] for weekly
  double progress;
  List<SubTask> subTasks;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.time = "",
    this.isCompleted = false,
    this.repeat = "none",
    this.repeatDays = const [],
    this.progress = 0.0,
    this.subTasks = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'time': time,
      'isCompleted': isCompleted ? 1 : 0,
      'repeat': repeat,
      'repeatDays': repeatDays.join(','),   // store as comma-separated string
      'progress': progress,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, {List<SubTask>? subTasks}) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dueDate: DateTime.parse(map['dueDate']),
      time: map['time'] ?? "",
      isCompleted: map['isCompleted'] == 1,
      repeat: map['repeat'] ?? "none",
      repeatDays: map['repeatDays'] != null && map['repeatDays'].toString().isNotEmpty
          ? map['repeatDays'].toString().split(',')
          : [],
      progress: (map['progress'] ?? 0).toDouble(),
      subTasks: subTasks ?? [],
    );
  }
}