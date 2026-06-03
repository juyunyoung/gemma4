import 'package:drift/drift.dart';

class LocalReports extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get reportDate => dateTime()();
  TextColumn get voiceRawText => text().nullable()();
  TextColumn get processedText => text().nullable()();
  TextColumn get itemsJson => text().nullable()(); // JSON 직렬화
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
