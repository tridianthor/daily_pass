import 'package:sqflite/sqflite.dart';
import '../../models/completion.dart';
import 'database_helper.dart';

class CompletionsDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Completion>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('completions', orderBy: 'completed_at DESC');
    return maps.map((map) => Completion.fromMap(map)).toList();
  }

  Future<Completion?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'completions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Completion.fromMap(maps.first);
  }

  Future<Completion?> getByActivityAndDate(String activityId, DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = _dateToString(date);
    final maps = await db.query(
      'completions',
      where: 'activity_id = ? AND completed_date = ?',
      whereArgs: [activityId, dateStr],
    );
    if (maps.isEmpty) return null;
    return Completion.fromMap(maps.first);
  }

  Future<List<Completion>> getByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = _dateToString(date);
    final maps = await db.query(
      'completions',
      where: 'completed_date = ?',
      whereArgs: [dateStr],
    );
    return maps.map((map) => Completion.fromMap(map)).toList();
  }

  Future<List<Completion>> getByActivity(String activityId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'completions',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'completed_date DESC',
    );
    return maps.map((map) => Completion.fromMap(map)).toList();
  }

  Future<void> insert(Completion completion) async {
    final db = await _dbHelper.database;
    await db.insert(
      'completions',
      completion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Completion completion) async {
    final db = await _dbHelper.database;
    await db.update(
      'completions',
      completion.toMap(),
      where: 'id = ?',
      whereArgs: [completion.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'completions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByActivity(String activityId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'completions',
      where: 'activity_id = ?',
      whereArgs: [activityId],
    );
  }

  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    await db.delete('completions');
  }

  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM completions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  String _dateToString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
