import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        dueDate TEXT NOT NULL,
        time TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        repeat TEXT NOT NULL DEFAULT 'none',
        repeatDays TEXT,
        progress REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add missing columns if upgrading from v1
      try {
        await db.execute("ALTER TABLE tasks ADD COLUMN repeat TEXT NOT NULL DEFAULT 'none'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tasks ADD COLUMN repeatDays TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tasks ADD COLUMN progress REAL NOT NULL DEFAULT 0.0");
      } catch (_) {}

      // Create subtasks table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subtasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER NOT NULL,
          title TEXT NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // ── INSERT ────────────────────────────────────────────────────────────────

  Future<int> insertTask(Task task) async {
    final db = await database;

    final taskMap = {
      'title': task.title,
      'description': task.description,
      'dueDate': task.dueDate.toIso8601String(),
      'time': task.time,
      'isCompleted': task.isCompleted ? 1 : 0,
      'repeat': task.repeat,
      'repeatDays': task.repeatDays.join(','),
      'progress': task.progress,
    };

    final taskId = await db.insert('tasks', taskMap);

    for (final sub in task.subTasks) {
      await db.insert('subtasks', {
        'taskId': taskId,
        'title': sub.title,
        'isCompleted': sub.isCompleted ? 1 : 0,
      });
    }

    return taskId;
  }

  // ── GET ALL ───────────────────────────────────────────────────────────────

  Future<List<Task>> getTasks() async {
    final db = await database;

    final taskMaps = await db.query('tasks', orderBy: 'dueDate ASC');
    final List<Task> tasks = [];

    for (final taskMap in taskMaps) {
      final subMaps = await db.query(
        'subtasks',
        where: 'taskId = ?',
        whereArgs: [taskMap['id']],
      );

      // Explicit cast — fixes List<dynamic> error
      final subTasks = subMaps
          .map((m) => SubTask(
        id: m['id'] as int?,
        taskId: m['taskId'] as int?,
        title: m['title'] as String,
        isCompleted: (m['isCompleted'] as int) == 1,
      ))
          .toList();

      tasks.add(Task(
        id: taskMap['id'] as int?,
        title: taskMap['title'] as String,
        description: taskMap['description'] as String? ?? '',
        dueDate: DateTime.parse(taskMap['dueDate'] as String),
        time: taskMap['time'] as String? ?? '',
        isCompleted: (taskMap['isCompleted'] as int) == 1,
        repeat: taskMap['repeat'] as String? ?? 'none',
        repeatDays: taskMap['repeatDays'] != null &&
            (taskMap['repeatDays'] as String).isNotEmpty
            ? (taskMap['repeatDays'] as String).split(',')
            : [],
        progress: (taskMap['progress'] as num?)?.toDouble() ?? 0.0,
        subTasks: subTasks,
      ));
    }

    return tasks;
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  Future<void> updateTask(Task task) async {
    if (task.id == null) return;
    final db = await database;

    await db.update(
      'tasks',
      {
        'title': task.title,
        'description': task.description,
        'dueDate': task.dueDate.toIso8601String(),
        'time': task.time,
        'isCompleted': task.isCompleted ? 1 : 0,
        'repeat': task.repeat,
        'repeatDays': task.repeatDays.join(','),
        'progress': task.progress,
      },
      where: 'id = ?',
      whereArgs: [task.id],
    );

    // Delete old subtasks and re-insert (simplest correct approach)
    await db.delete('subtasks', where: 'taskId = ?', whereArgs: [task.id]);

    for (final sub in task.subTasks) {
      await db.insert('subtasks', {
        'taskId': task.id,
        'title': sub.title,
        'isCompleted': sub.isCompleted ? 1 : 0,
      });
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('subtasks', where: 'taskId = ?', whereArgs: [id]);
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ── CLOSE ─────────────────────────────────────────────────────────────────

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}