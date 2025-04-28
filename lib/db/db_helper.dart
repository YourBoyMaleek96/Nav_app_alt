import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';

/// A helper class for managing the database
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static final _store = intMapStoreFactory.store('notes');
  static Database? _db;

  /// Opens the database
  Future<Database> get database async {
    if (_db != null) return _db!;

    if (kIsWeb) {
      _db = await databaseFactoryWeb.openDatabase('notes.db');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/notes.db';
      _db = await databaseFactoryIo.openDatabase(dbPath);
    }

    return _db!;
  }

  /// Inserts a note into the database
  Future<int> insertNote(Note note) async {
    final dbClient = await database;
    final key = await _store.add(dbClient, note.toMap());
    return key;
  }

  /// Updates a note in the database
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

  /// Updates a note in the database
  Future<int> deleteNote(int id) async {
    final dbClient = await database;
    return await _store.delete(
      dbClient,
      finder: Finder(filter: Filter.byKey(id)),
    );
  }
}
