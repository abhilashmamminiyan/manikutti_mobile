import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../screens/dashboard_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/smart_scan_screen.dart';
import '../screens/bills_dashboard.dart';
import '../screens/screenshots_screen.dart';
import '../services/api_service.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF006972),
            ),
            child: Text(
              l10n.appTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontFamily: 'Manrope',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: Text(l10n.dashboard),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(l10n.bills),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const BillsDashboard()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: Text(l10n.smartScan),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SmartScanScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.screenshots),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ScreenshotsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.settings),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: Text(l10n.logout),
            onTap: () async {
              await ApiService.instance.clearSession();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
