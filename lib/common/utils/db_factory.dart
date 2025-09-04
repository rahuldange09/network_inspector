// Resolves DatabaseFactory for current platform (web vs others)
import 'package:sqflite_common/sqlite_api.dart';

import 'db_factory_io.dart' if (dart.library.html) 'db_factory_web.dart';

DatabaseFactory getDatabaseFactory() => resolvedDatabaseFactory();
