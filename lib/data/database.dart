import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

class Conversations extends Table {
  TextColumn get id => text().withDefault(Constant(const Uuid().v4()))();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get folderId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get aiProviderId => text()();
  TextColumn get modelId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text().withDefault(Constant(const Uuid().v4()))();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get role => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class MessageBlocks extends Table {
  TextColumn get id => text().withDefault(Constant(const Uuid().v4()))();
  TextColumn get messageId => text().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()();
  TextColumn get content => text()();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Folders extends Table {
  TextColumn get id => text().withDefault(Constant(const Uuid().v4()))();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  TextColumn get iconName => text().withDefault(const Constant('folder'))();
  TextColumn get colorHex => text().withDefault(const Constant('#4A8CDC'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text().withDefault(Constant(const Uuid().v4()))();
  TextColumn get name => text().unique()();
  TextColumn get colorHex => text().withDefault(const Constant('#4A8CDC'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ConversationTags extends Table {
  TextColumn get conversationId => text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {conversationId, tagId};
}

@DriftDatabase(tables: [Conversations, Messages, MessageBlocks, Folders, Tags, ConversationTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) {
        return m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 1) {
          // Add future migrations here
        }
      },
      beforeOpen: (details) async {
        if (details.wasCreated) {
          // Create default folders
          await into(
            folders,
          ).insert(FoldersCompanion(name: const Value('All Conversations'), iconName: const Value('folder'), colorHex: const Value('#4A8CDC')));
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'nexon.sqlite'));

    if (kDebugMode) {
      print('Database path: ${file.path}');
    }

    return NativeDatabase.createInBackground(file);
  });
}
