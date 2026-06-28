/// 错题猎手 - SQLite 本地数据库管理
/// 来源：技术设计文档 V1.0 §4.1
/// 包含 local_questions、local_images、sync_queue 三张表
library;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// 本地数据库管理器
class DatabaseHelper {
  DatabaseHelper._();

  static const String _dbName = 'errorhunter.db';
  static const int _dbVersion = 1;

  /// 数据库文件名（公开，供存储统计等场景读取文件大小）
  static const String dbName = _dbName;

  // ─── Table Names ────────────────────────────────────────
  static const String tableLocalQuestions = 'local_questions';
  static const String tableLocalImages = 'local_images';
  static const String tableSyncQueue = 'sync_queue';

  // ─── Singleton ──────────────────────────────────────────
  static DatabaseHelper? _instance;
  static Database? _database;

  /// 获取单例实例
  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  /// 获取数据库实例
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  // ─── Table Creation ─────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    // 本地错题表 — 离线缓存 + 编辑暂存
    await db.execute('''
      CREATE TABLE $tableLocalQuestions (
        id              TEXT PRIMARY KEY,
        remote_id       TEXT,
        image_path      TEXT NOT NULL,
        ocr_text        TEXT,
        my_answer       TEXT,
        correct_answer  TEXT,
        error_category  TEXT NOT NULL DEFAULT 'UNKNOWN',
        sub_categories  TEXT DEFAULT '[]',
        status          TEXT NOT NULL DEFAULT 'NOT_STARTED',
        knowledge_points TEXT DEFAULT '[]',
        custom_tags     TEXT DEFAULT '[]',
        solution_steps  TEXT DEFAULT '[]',
        subject         TEXT NOT NULL DEFAULT '数学',
        grade           TEXT,
        current_review_round INTEGER NOT NULL DEFAULT 0,
        total_review_rounds  INTEGER NOT NULL DEFAULT 5,
        created_at      TEXT NOT NULL,
        updated_at      TEXT,
        deleted_at      TEXT,
        is_deleted      INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 本地图片表 — 拍照/裁剪后的临时存储
    await db.execute('''
      CREATE TABLE $tableLocalImages (
        id              TEXT PRIMARY KEY,
        question_id     TEXT NOT NULL,
        file_path       TEXT NOT NULL,
        file_size       INTEGER,
        mime_type       TEXT DEFAULT 'image/jpeg',
        sort_order      INTEGER NOT NULL DEFAULT 0,
        created_at      TEXT NOT NULL,
        FOREIGN KEY (question_id) REFERENCES $tableLocalQuestions(id) ON DELETE CASCADE
      )
    ''');

    // 同步队列表 — 记录待同步的变更操作
    await db.execute('''
      CREATE TABLE $tableSyncQueue (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type     TEXT NOT NULL,
        entity_id       TEXT NOT NULL,
        action          TEXT NOT NULL,
        payload         TEXT,
        retry_count     INTEGER NOT NULL DEFAULT 0,
        max_retries     INTEGER NOT NULL DEFAULT 5,
        created_at      TEXT NOT NULL,
        last_attempt_at TEXT,
        error_message   TEXT,
        status          TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');

    // 创建索引提升查询性能
    await db.execute(
      'CREATE INDEX idx_local_questions_status ON $tableLocalQuestions(status)',
    );
    await db.execute(
      'CREATE INDEX idx_local_questions_deleted ON $tableLocalQuestions(is_deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_local_images_question ON $tableLocalImages(question_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON $tableSyncQueue(status)',
    );
  }

  /// 数据库升级迁移
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2 迁移示例：
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE $tableLocalQuestions ADD COLUMN ...');
    // }
  }

  /// 数据库降级处理
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    // 降级策略：重建数据库（生产环境应更谨慎）
    await db.execute('DROP TABLE IF EXISTS $tableSyncQueue');
    await db.execute('DROP TABLE IF EXISTS $tableLocalImages');
    await db.execute('DROP TABLE IF EXISTS $tableLocalQuestions');
    await _onCreate(db, newVersion);
  }

  // ─── CRUD: Local Questions ──────────────────────────────

  /// 插入本地错题
  Future<int> insertQuestion(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(tableLocalQuestions, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 查询所有未删除的本地错题
  Future<List<Map<String, dynamic>>> getQuestions({
    String? status,
    String? subject,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final where = <String>['is_deleted = 0'];
    final args = <dynamic>[];

    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (subject != null) {
      where.add('subject = ?');
      args.add(subject);
    }

    return db.query(
      tableLocalQuestions,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// 按 ID 查询单条错题
  Future<Map<String, dynamic>?> getQuestionById(String id) async {
    final db = await database;
    final results = await db.query(
      tableLocalQuestions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  /// 更新错题
  Future<int> updateQuestion(String id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update(
      tableLocalQuestions,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 软删除错题（移入回收站）
  Future<int> softDeleteQuestion(String id) async {
    final db = await database;
    return db.update(
      tableLocalQuestions,
      {
        'is_deleted': 1,
        'deleted_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 恢复已删除的错题
  Future<int> restoreQuestion(String id) async {
    final db = await database;
    return db.update(
      tableLocalQuestions,
      {
        'is_deleted': 0,
        'deleted_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 永久删除错题
  Future<int> permanentlyDeleteQuestion(String id) async {
    final db = await database;
    return db.delete(
      tableLocalQuestions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取回收站中的错题
  Future<List<Map<String, dynamic>>> getRecycleBinQuestions() async {
    final db = await database;
    return db.query(
      tableLocalQuestions,
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
  }

  /// 清空回收站（删除超过30天或全部）
  Future<int> clearRecycleBin({int olderThanDays = 0}) async {
    final db = await database;
    if (olderThanDays > 0) {
      final cutoff =
          DateTime.now().subtract(Duration(days: olderThanDays)).toIso8601String();
      return db.delete(
        tableLocalQuestions,
        where: 'is_deleted = 1 AND deleted_at < ?',
        whereArgs: [cutoff],
      );
    }
    return db.delete(
      tableLocalQuestions,
      where: 'is_deleted = 1',
    );
  }

  // ─── CRUD: Local Images ─────────────────────────────────

  /// 插入本地图片记录
  Future<int> insertImage(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(tableLocalImages, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 获取某错题的所有图片
  Future<List<Map<String, dynamic>>> getImagesByQuestionId(
      String questionId) async {
    final db = await database;
    return db.query(
      tableLocalImages,
      where: 'question_id = ?',
      whereArgs: [questionId],
      orderBy: 'sort_order ASC',
    );
  }

  /// 删除某错题的所有图片
  Future<int> deleteImagesByQuestionId(String questionId) async {
    final db = await database;
    return db.delete(
      tableLocalImages,
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
  }

  // ─── CRUD: Sync Queue ───────────────────────────────────

  /// 添加同步任务
  Future<int> enqueueSync({
    required String entityType,
    required String entityId,
    required String action,
    String? payload,
  }) async {
    final db = await database;
    return db.insert(tableSyncQueue, {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'PENDING',
    });
  }

  /// 获取待同步的任务
  Future<List<Map<String, dynamic>>> getPendingSyncTasks({int limit = 20}) async {
    final db = await database;
    return db.query(
      tableSyncQueue,
      where: "status = 'PENDING'",
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// 标记同步任务为完成
  Future<int> markSyncCompleted(int id) async {
    final db = await database;
    return db.update(
      tableSyncQueue,
      {'status': 'COMPLETED'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 标记同步任务为失败并增加重试计数
  Future<int> markSyncFailed(int id, String errorMessage) async {
    final db = await database;
    return db.rawUpdate('''
      UPDATE $tableSyncQueue
      SET status = CASE WHEN retry_count >= max_retries THEN 'FAILED' ELSE 'PENDING' END,
          retry_count = retry_count + 1,
          last_attempt_at = ?,
          error_message = ?
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), errorMessage, id]);
  }

  /// 清除已完成/已失败的同步记录
  Future<int> cleanSyncQueue() async {
    final db = await database;
    return db.delete(
      tableSyncQueue,
      where: "status IN ('COMPLETED', 'FAILED')",
    );
  }

  // ─── Utilities ──────────────────────────────────────────

  /// 获取各表记录数（用于存储管理页面）
  Future<Map<String, int>> getTableCounts() async {
    final db = await database;
    final qCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableLocalQuestions')) ??
        0;
    final iCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableLocalImages')) ??
        0;
    final sCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableSyncQueue')) ??
        0;
    return {
      'questions': qCount,
      'images': iCount,
      'syncQueue': sCount,
    };
  }

  /// 关闭数据库连接
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }

  /// 重置单例（仅测试使用）
  static void resetInstance() {
    _instance = null;
    _database = null;
  }
}
