import 'package:drift/drift.dart';

class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get ingredients => text()();
  TextColumn get instructions => text()();
  TextColumn? get imageUrl => text().nullable()();
  TextColumn? get tags => text().nullable()();
  TextColumn? get sourceUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
