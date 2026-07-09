import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';

class ScreenshotsScreen extends StatelessWidget {
  const ScreenshotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.screenshots)),
      drawer: const AppDrawer(),
      body: Center(
        child: Text(l10n.screenshots),
      ),
    );
  }
}
