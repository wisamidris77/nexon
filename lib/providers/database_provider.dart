import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/data/database.dart';
import 'package:nexon/data/conversation_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ConversationRepository(db);
});
