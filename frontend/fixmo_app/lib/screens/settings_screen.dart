import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/theme_provider.dart';
import '../providers/app_state_provider.dart';

/// Simplified settings: dark aesthetic, light/dark toggle only.
/// Keeps: Location settings, Notification toggles, About section.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoDetectLocation = true;
  bool _showLocationOnMap = true;
  bool _reportNotifications = true;
  bool _communityUpdates = true;
  bool _emergencyAlerts = true;
  bool _pushNotifications = true;
  bool _notificationSound = true;

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _primary = Color(0xFF00D9A3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer2<ThemeProvider, AppStateProvider>(
        builder: (context, themeProvider, appState, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _sectionCard(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Dark mode',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      themeProvider.isDarkMode ? 'On' : 'Off',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      activeColor: _primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Location',
                icon: Icons.location_on_outlined,
                children: [
                  _switchTile(
                    'Auto-detect municipality',
                    'Use GPS to detect your area',
                    _autoDetectLocation,
                    (v) => setState(() => _autoDetectLocation = v),
                  ),
                  _switchTile(
                    'Show location on map',
                    'Display your position on the map',
                    _showLocationOnMap,
                    (v) => setState(() => _showLocationOnMap = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Notifications',
                icon: Icons.notifications_outlined,
                children: [
                  _switchTile(
                    'Report status updates',
                    'When your reports are updated',
                    _reportNotifications,
                    (v) => setState(() => _reportNotifications = v),
                  ),
                  _switchTile(
                    'Community updates',
                    'News from your municipality',
                    _communityUpdates,
                    (v) => setState(() => _communityUpdates = v),
                  ),
                  _switchTile(
                    'Emergency alerts',
                    'Critical notifications',
                    _emergencyAlerts,
                    (v) => setState(() => _emergencyAlerts = v),
                  ),
                  _switchTile(
                    'Push notifications',
                    'Receive notifications on device',
                    _pushNotifications,
                    (v) => setState(() => _pushNotifications = v),
                  ),
                  _switchTile(
                    'Notification sound',
                    'Sound for new notifications',
                    _notificationSound,
                    (v) => setState(() => _notificationSound = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'About',
                icon: Icons.info_outline,
                children: [
                  _infoRow('App', AppConfig.appName),
                  _infoRow('Version', AppConfig.appVersion),
                  _infoRow('Organization', AppConfig.appOrganization),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Made with ❤️ for Mauritius',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _primary,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
