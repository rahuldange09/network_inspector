import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

DatabaseFactory resolvedDatabaseFactory() {
  final options = SqfliteFfiWebOptions(
    // Flutter serves package assets under assets/packages/<package>/...
    sqlite3WasmUri:
        Uri.parse('assets/packages/network_inspector/assets/ffi/sqlite3.wasm'),
    sharedWorkerUri:
        Uri.parse('assets/packages/network_inspector/assets/ffi/sqflite_sw.js'),
  );
  return createDatabaseFactoryFfiWeb(options: options);
}
