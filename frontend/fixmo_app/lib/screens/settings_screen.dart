import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_state_provider.dart';
import '../utils/settings_preferences.dart';

/// Settings screen with 9 sections following the Deep Agent specification.
///
/// All colors sourced from [Theme.of(context)] so light/dark themes
/// work correctly. Toggles persist via [SettingsPreferences].
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsPreferences _prefs = SettingsPreferences();
  bool _prefsLoaded = false;
  List<String> _municipalityNames = [];
  String? _cacheSizeText;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadMunicipalities();
    _calculateCacheSize();
  }

  Future<void> _loadPreferences() async {
    await _prefs.load();
    if (mounted) setState(() => _prefsLoaded = true);
  }

  Future<void> _loadMunicipalities() async {
    try {
      final raw = await rootBundle.loadString('assets/data/mauritius_municipalities.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['municipalities'] as List).map((m) => m['name'] as String).toList();
      if (mounted) setState(() => _municipalityNames = list);
    } catch (_) {}
  }

  Future<void> _calculateCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      final bytes = await _dirSize(dir);
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
      if (mounted) setState(() => _cacheSizeText = '$mb MB');
    } catch (_) {
      if (mounted) setState(() => _cacheSizeText = 'N/A');
    }
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    }
    return total;
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cached data?'),
        content: const Text('This will remove cached images and temporary files. Your reports and settings are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          await entity.delete(recursive: true);
        }
      }
      _calculateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear cache: $e')));
      }
    }
  }

  Future<void> _clearLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all local data?'),
        content: const Text('This will reset all preferences, clear cached data, and sign you out. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear Everything', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _prefs.clearAll();
    await _clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All local data cleared')));
    }
  }

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF1A1A1A);
  static const Color _primary = Color(0xFF00D9A3);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!_prefsLoaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: cs.surface,
          elevation: 0,
          title: Text('Settings', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Settings', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final authProvider = context.watch<AuthProvider>();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 1. Account
              _buildAccountSection(cs, tt, authProvider),
              const SizedBox(height: 16),
              // 2. Appearance
              _buildAppearanceSection(cs, tt, themeProvider),
              const SizedBox(height: 16),
              // 3. Notifications
              _buildNotificationsSection(cs, tt),
              const SizedBox(height: 16),
              // 4. Location
              _buildLocationSection(cs, tt),
              const SizedBox(height: 16),
              // 5. Municipality
              _buildMunicipalitySection(cs, tt),
              const SizedBox(height: 16),
              // 6. Data & Storage
              _buildDataStorageSection(cs, tt),
              const SizedBox(height: 16),
              // 7. Accessibility
              _buildAccessibilitySection(cs, tt),
              const SizedBox(height: 16),
              // 8. Privacy & Security
              _buildPrivacySection(cs, tt, authProvider),
              const SizedBox(height: 16),
              // 9. About
              _buildAboutSection(cs, tt),
              const SizedBox(height: 24),
              Center(child: Text('Made with \u2764\ufe0f for Mauritius', style: tt.bodySmall)),
            ],
          );
        },
      ),
    );
  }

  // ── 1. Account ────────────────────────────────────────────────────

  Widget _buildAccountSection(ColorScheme cs, TextTheme tt, AuthProvider auth) {
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'Account',
      icon: Icons.person_outlined,
      children: [
        if (auth.isAnonymous) ...[
          _infoRow(cs, tt, 'Status', 'Anonymous user'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sign-in coming in a future update')),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign In / Create Account'),
            ),
          ),
        ] else ...[
          _infoRow(cs, tt, 'Email', auth.user?.email ?? 'N/A'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await auth.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out')),
                  );
                }
              },
              icon: Icon(Icons.logout, color: cs.error),
              label: Text('Sign Out', style: TextStyle(color: cs.error)),
            ),
          ),
        ],
      ],
    );
  }

  // ── 2. Appearance ─────────────────────────────────────────────────

  Widget _buildAppearanceSection(ColorScheme cs, TextTheme tt, ThemeProvider themeProvider) {
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'Appearance',
      icon: Icons.palette_outlined,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Dark mode', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
          subtitle: Text(themeProvider.isDarkMode ? 'On' : 'Off', style: tt.bodySmall),
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
            activeColor: cs.primary,
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Text('Language', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text('App language preference', style: tt.bodySmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('EN')),
            ButtonSegment(value: 'fr', label: Text('FR')),
            ButtonSegment(value: 'mfe', label: Text('KR')),
          ],
          selected: {_prefs.language},
          onSelectionChanged: (v) async {
            await _prefs.setLanguage(v.first);
            setState(() {});
          },
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return cs.onPrimary;
              return cs.onSurface;
            }),
          ),
        ),
      ],
    );
  }

  // ── 3. Notifications ──────────────────────────────────────────────

  Widget _buildNotificationsSection(ColorScheme cs, TextTheme tt) {
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      children: [
        _switchTile(cs, tt, 'Push notifications', 'Receive notifications on device', _prefs.pushNotifications, (v) async {
          await _prefs.setPushNotifications(v);
          setState(() {});
        }),
        _switchTile(cs, tt, 'Report status updates', 'When your reports are updated', _prefs.reportNotifications, (v) async {
          await _prefs.setReportNotifications(v);
          setState(() {});
        }),
        _switchTile(cs, tt, 'Community updates', 'News from your municipality', _prefs.communityUpdates, (v) async {
          await _prefs.setCommunityUpdates(v);
          setState(() {});
        }),
        // Emergency alerts — always on
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency alerts', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('Always enabled for safety', style: tt.bodySmall),
                  ],
                ),
              ),
              Switch(value: true, onChanged: null, activeColor: cs.primary),
            ],
          ),
        ),
        _switchTile(cs, tt, 'Notification sound', 'Sound for new notifications', _prefs.notificationSound, (v) async {
          await _prefs.setNotificationSound(v);
          setState(() {});
        }),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Text('Nearby issues radius', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text('Get notified about issues within this distance', style: tt.bodySmall),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _prefs.nearbyRadius,
                min: 5,
                max: 50,
                divisions: 9,
                label: '${_prefs.nearbyRadius.round()} km',
                activeColor: cs.primary,
                onChanged: (v) async {
                  await _prefs.setNearbyRadius(v);
                  setState(() {});
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text('${_prefs.nearbyRadius.round()} km', style: tt.bodySmall, textAlign: TextAlign.end),
            ),
          ],
        ),
      ],
    );
  }

  // ── 4. Location ───────────────────────────────────────────────────

  Widget _buildLocationSection(ColorScheme cs, TextTheme tt) {
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'Location',
      icon: Icons.location_on_outlined,
      children: [
        _switchTile(cs, tt, 'Auto-detect municipality', 'Use GPS to detect your area', _prefs.autoDetectLocation, (v) async {
          await _prefs.setAutoDetectLocation(v);
          setState(() {});
        }),
        _switchTile(cs, tt, 'Show location on map', 'Display your position on the map', _prefs.showLocationOnMap, (v) async {
          await _prefs.setShowLocationOnMap(v);
          setState(() {});
        }),
        if (_municipalityNames.isNotEmpty) ...[
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text('Default municipality', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('Fallback when GPS is unavailable', style: tt.bodySmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _prefs.defaultMunicipality,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text('Select municipality'),
            isExpanded: true,
            items: _municipalityNames.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) async {
              await _prefs.setDefaultMunicipality(v);
              setState(() {});
            },
          ),
        ],
        const SizedBox(height: 10),
        _tappableRow(cs, tt, 'Location permissions', 'Open device settings', Icons.open_in_new, () {
          openAppSettings();
        }),
      ],
    );
  }

  // ── 5. Municipality ───────────────────────────────────────────────

  Widget _buildMunicipalitySection(ColorScheme cs, TextTheme tt) {
    final appState = context.watch<AppStateProvider>();
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'Municipality',
      icon: Icons.account_balance_outlined,
      children: [
        _infoRow(cs, tt, 'Current', appState.selectedMunicipality ?? 'Auto-detecting...'),
        const SizedBox(height: 8),
        _comingSoonRow(cs, tt, 'Saved areas', 'Save favourite areas for alerts'),
      ],
    );
  }

  // ── 6. Data & Storage ─────────────────────────────────────────────

  Widget _buildDataStorageSection(ColorScheme cs, TextTheme tt) {
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'Data & Storage',
      icon: Icons.storage_outlined,
      children: [
        _infoRow(cs, tt, 'Cached data', _cacheSizeText ?? 'Calculating...'),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _clearCache,
            child: const Text('Clear cache'),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Text('Image upload quality', style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'high', label: Text('High')),
            ButtonSegment(value: 'medium', label: Text('Medium')),
            ButtonSegment(value: 'low', label: Text('Low')),
          ],
          selected: {_prefs.imageQuality},
          onSelectionChanged: (v) async {
            await _prefs.setImageQuality(v.first);
            setState(() {});
          },
        ),
        const SizedBox(height: 10),
        _switchTile(cs, tt, 'Download images on Wi-Fi only', 'Save mobile data', _prefs.wifiOnlyImages, (v) async {
          await _prefs.setWifiOnlyImages(v);
          setState(() {});
        }),
        _switchTile(cs, tt, 'Auto-sync on Wi-Fi only', 'Sync reports when on Wi-Fi', _prefs.wifiOnlySync, (v) async {
          await _prefs.setWifiOnlySync(v);
          setState(() {});
        }),
      ],
    );
  }

  // ── 7. Accessibility ──────────────────────────────────────────────

  Widget _buildAccessibilitySection(ColorScheme cs, TextTheme tt) {
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'Accessibility',
      icon: Icons.accessibility_new_outlined,
      children: [
        _switchTile(cs, tt, 'Large text mode', 'Increase text size throughout the app', _prefs.largeText, (v) async {
          await _prefs.setLargeText(v);
          setState(() {});
        }),
        _switchTile(cs, tt, 'High contrast mode', 'Enhanced color contrast', _prefs.highContrast, (v) async {
          await _prefs.setHighContrast(v);
          setState(() {});
        }),
        _switchTile(cs, tt, 'Reduce animations', 'Minimise motion effects', _prefs.reduceAnimations, (v) async {
          await _prefs.setReduceAnimations(v);
          setState(() {});
        }),
        _switchTile(cs, tt, 'Screen reader hints', 'Extra labels for assistive technology', _prefs.screenReaderHints, (v) async {
          await _prefs.setScreenReaderHints(v);
          setState(() {});
        }),
      ],
    );
  }

  // ── 8. Privacy & Security ─────────────────────────────────────────

  Widget _buildPrivacySection(ColorScheme cs, TextTheme tt, AuthProvider auth) {
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'Privacy & Security',
      icon: Icons.lock_outline,
      children: [
        _infoRow(cs, tt, 'Device ID', auth.user?.id.substring(0, 8) ?? 'N/A'),
        const SizedBox(height: 4),
        _tappableRow(cs, tt, 'Clear local data', 'Remove all preferences and cache', Icons.delete_outline, _clearLocalData),
        _comingSoonRow(cs, tt, 'Export my data', 'Download your data (GDPR)'),
        if (!auth.isAnonymous) _comingSoonRow(cs, tt, 'Delete account', 'Permanently remove your account'),
      ],
    );
  }

  // ── 9. About ──────────────────────────────────────────────────────

  Widget _buildAboutSection(ColorScheme cs, TextTheme tt) {
    return _sectionCard(
      cs: cs, tt: tt,
      title: 'About',
      icon: Icons.info_outline,
      children: [
        _infoRow(cs, tt, 'App', AppConfig.appName),
        _infoRow(cs, tt, 'Version', AppConfig.appVersion),
        _infoRow(cs, tt, 'Organization', AppConfig.appOrganization),
        const Divider(height: 16),
        _tappableRow(cs, tt, 'Terms of Service', '', Icons.open_in_new, () {
          launchUrl(Uri.parse('https://fixmo.mu/terms'), mode: LaunchMode.externalApplication);
        }),
        _tappableRow(cs, tt, 'Privacy Policy', '', Icons.open_in_new, () {
          launchUrl(Uri.parse('https://fixmo.mu/privacy'), mode: LaunchMode.externalApplication);
        }),
        _tappableRow(cs, tt, 'Open Source Licenses', '', Icons.chevron_right, () {
          showLicensePage(
            context: context,
            applicationName: AppConfig.appName,
            applicationVersion: AppConfig.appVersion,
          );
        }),
        _tappableRow(cs, tt, 'Contact Support', '', Icons.email_outlined, () {
          launchUrl(Uri.parse('mailto:support@fixmo.mu'));
        }),
      ],
    );
  }

  // ── Reusable helpers ──────────────────────────────────────────────

  Widget _sectionCard({
    required ColorScheme cs,
    required TextTheme tt,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _switchTile(ColorScheme cs, TextTheme tt, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: tt.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: cs.primary),
        ],
      ),
    );
  }

  Widget _infoRow(ColorScheme cs, TextTheme tt, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodySmall),
          Flexible(child: Text(value, style: tt.bodyMedium, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _tappableRow(ColorScheme cs, TextTheme tt, String title, String subtitle, IconData trailing, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: tt.bodySmall),
                  ],
                ],
              ),
            ),
            Icon(trailing, color: cs.onSurface.withOpacity(0.4), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _comingSoonRow(ColorScheme cs, TextTheme tt, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: tt.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Soon', style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
