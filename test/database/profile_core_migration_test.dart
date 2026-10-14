import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profiles from schema 4 open as mihomo profiles', () async {
    final db = Database(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE profiles (
              id INTEGER NOT NULL PRIMARY KEY,
              label TEXT NOT NULL,
              current_group_name TEXT NULL,
              url TEXT NOT NULL,
              last_update_date INTEGER NULL,
              overwrite_type TEXT NOT NULL,
              script_id INTEGER NULL,
              auto_update_duration_millis INTEGER NOT NULL,
              subscription_info TEXT NULL,
              auto_update INTEGER NOT NULL,
              selected_map TEXT NOT NULL,
              computed_selected_map TEXT NOT NULL DEFAULT '{}',
              unfold_set TEXT NOT NULL,
              "order" INTEGER NULL
            )''');
          raw.execute(
            "INSERT INTO profiles VALUES (1, 'Home', NULL, 'https://x', NULL, "
            "'standard', NULL, 86400000, NULL, 1, '{}', '{}', '[]', 0)",
          );
          raw.userVersion = 4;
        },
      ),
    );
    addTearDown(db.close);
    final profiles = await db.profilesDao.query().get();
    expect(profiles.single.label, 'Home');
    expect(profiles.single.core, ProfileCore.mihomo);
    expect(profiles.single.overwriteType, OverwriteType.standard);
  });

  test('the core round-trips through the table', () async {
    final db = Database(NativeDatabase.memory());
    addTearDown(db.close);
    await db.profilesDao.setAll([
      Profile.normal(label: 'Xray').copyWith(core: ProfileCore.xray),
    ]);
    final profiles = await db.profilesDao.query().get();
    expect(profiles.single.core, ProfileCore.xray);
  });
}
