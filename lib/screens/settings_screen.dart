import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.language),
            trailing: DropdownButton<String>(
              value: Localizations.localeOf(context).languageCode,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ml', child: Text('മലയാളം')),
              ],
              onChanged: (value) async {
                if (value != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('languageCode', value);
                  if (context.mounted) {
                    MyApp.setLocale(context, Locale(value));
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
