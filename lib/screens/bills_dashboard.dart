import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';

class BillsDashboard extends StatelessWidget {
  const BillsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bills)),
      drawer: const AppDrawer(),
      body: Center(child: Text(l10n.bills)),
    );
  }
}
