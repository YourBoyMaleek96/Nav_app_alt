import 'dart:convert';
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart' show databaseFactoryWeb;

import '../models/note_model.dart';

/// DBHelper class that handles database operations using sembast for web/mobile.
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static final _store = intMapStoreFactory.store('notes');
  static Database? _db;

  /// Returns the database instance.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await databaseFactoryWeb.openDatabase('notes.db');
    return _db!;
  }

  /// Inserts a note into the database.
  Future<int> insertNote(Note note) async {
    final dbClient = await database;
    final key = await _store.add(dbClient, note.toMap());
    return key;
  }

  /// Retrieves all notes from the database.
  Future<List<Note>> getNotes() async {
    final dbClient = await database;
    final records = await _store.find(
      dbClient,
      finder: Finder(sortOrders: [SortOrder('dateTime', false)]),
    );
    return records.map((snapshot) {
      final note = Note.fromMap(snapshot.value);
      return note.copyWith(id: snapshot.key);
    }).toList();
  }

  /// Deletes a note by ID.
  Future<int> deleteNote(int id) async {
    final dbClient = await database;
    return await _store.delete(
      dbClient,
      finder: Finder(filter: Filter.byKey(id)),
    );
  }
}
