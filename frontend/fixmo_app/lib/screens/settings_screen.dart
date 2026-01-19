import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/app_state_provider.dart';
import '../config/app_config.dart';

/// Settings screen for app configuration
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
  bool _emailNotifications = false;
  bool _notificationSound = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 2,
      ),
      body: Consumer2<ThemeProvider, AppStateProvider>(
        builder: (context, themeProvider, appState, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Appearance',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Choose your preferred theme',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Theme Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: AppTheme.values.length,
                        itemBuilder: (context, index) {
                          final theme = AppTheme.values[index];
                          final isSelected = themeProvider.currentTheme == theme;
                          
                          return GestureDetector(
                            onTap: () => themeProvider.setTheme(theme),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? theme.primaryColor.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected 
                                      ? theme.primaryColor
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      theme.icon,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    theme.displayName,
                                    style: TextStyle(
                                      fontWeight: isSelected 
                                          ? FontWeight.bold 
                                          : FontWeight.w500,
                                      color: isSelected 
                                          ? theme.primaryColor
                                          : Theme.of(context).textTheme.bodyMedium?.color,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Location Settings',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.gps_fixed,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: const Text('Auto-detect Municipality'),
                        subtitle: const Text('Automatically detect your municipality using GPS'),
                        trailing: Switch(
                          value: _autoDetectLocation,
                          onChanged: (value) {
                            setState(() {
                              _autoDetectLocation = value;
                            });
                          },
                        ),
                      ),
                      
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.map,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: const Text('Show Location on Map'),
                        subtitle: const Text('Display your location on the map'),
                        trailing: Switch(
                          value: _showLocationOnMap,
                          onChanged: (value) {
                            setState(() {
                              _showLocationOnMap = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Notifications & Alerts - Enhanced
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                            color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                          Text(
                            'Notifications & Alerts',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manage your notification preferences',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      
                      // Push Notifications
                      _buildNotificationTile(
                        icon: Icons.phone_android,
                        iconColor: const Color(0xFF6C63FF),
                        title: 'Push Notifications',
                        subtitle: 'Receive notifications on your device',
                        value: _pushNotifications,
                        onChanged: (value) {
                          setState(() {
                            _pushNotifications = value;
                          });
                        },
                      ),
                      
                      // Email Notifications
                      _buildNotificationTile(
                        icon: Icons.email_outlined,
                        iconColor: const Color(0xFF4ECDC4),
                        title: 'Email Notifications',
                        subtitle: 'Get updates via email',
                        value: _emailNotifications,
                        onChanged: (value) {
                          setState(() {
                            _emailNotifications = value;
                          });
                        },
                      ),
                      
                      // Notification Sound
                      _buildNotificationTile(
                        icon: Icons.volume_up_rounded,
                        iconColor: Colors.orange,
                        title: 'Notification Sound',
                        subtitle: 'Play sound for new notifications',
                        value: _notificationSound,
                        onChanged: (value) {
                          setState(() {
                            _notificationSound = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      
                      // Notification Types
                      Text(
                        'Notification Types',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildNotificationTile(
                        icon: Icons.assignment_turned_in,
                        iconColor: Colors.green,
                        title: 'Report Status Updates',
                        subtitle: 'Get notified when your reports are updated',
                          value: _reportNotifications,
                          onChanged: (value) {
                            setState(() {
                              _reportNotifications = value;
                            });
                          },
                        ),
                      
                      _buildNotificationTile(
                        icon: Icons.people_outline,
                        iconColor: Colors.blue,
                        title: 'Community Updates',
                        subtitle: 'News and updates from your municipality',
                          value: _communityUpdates,
                          onChanged: (value) {
                            setState(() {
                              _communityUpdates = value;
                            });
                          },
                        ),
                      
                      _buildNotificationTile(
                        icon: Icons.warning_amber_rounded,
                        iconColor: Colors.red,
                        title: 'Emergency Alerts',
                        subtitle: 'Critical alerts and emergency notifications',
                          value: _emergencyAlerts,
                        showDivider: false,
                          onChanged: (value) {
                            setState(() {
                              _emergencyAlerts = value;
                            });
                          },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Report Management
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Report Management',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.history,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: const Text('View Report History'),
                        subtitle: const Text('See all your submitted reports'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.pushNamed(context, '/history');
                        },
                      ),
                      
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.analytics,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: const Text('Municipality Statistics'),
                        subtitle: Text('View stats for ${appState.selectedMunicipality ?? "your area"}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          _showStatisticsDialog();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Emergency Contacts - Enhanced Design
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.emergency_rounded,
                            color: Colors.red,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                          Text(
                            'Emergency Contacts',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Quick access to emergency services',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      _buildEmergencyContact(
                        'Police Emergency',
                        '999',
                        Icons.local_police,
                        Colors.blue.shade700,
                      ),
                      _buildEmergencyContact(
                        'Fire Department',
                        '995',
                        Icons.local_fire_department,
                        Colors.red.shade600,
                      ),
                      _buildEmergencyContact(
                        'Medical Emergency',
                        '114',
                        Icons.local_hospital,
                        Colors.green.shade600,
                      ),
                      _buildEmergencyContact(
                        'Municipality Office',
                        '8924 5000',
                        Icons.business,
                        const Color(0xFF6C63FF),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // App Info Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'App Information',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildInfoRow(
                        context,
                        'App Name',
                        AppConfig.appName,
                        Icons.apps,
                      ),
                      _buildInfoRow(
                        context,
                        'Version',
                        AppConfig.appVersion,
                        Icons.tag,
                      ),
                      _buildInfoRow(
                        context,
                        'Organization',
                        AppConfig.appOrganization,
                        Icons.business,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      'Made with ❤️ for Mauritius',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Help make our communities better! 🇲🇺',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: iconColor,
              ),
            ],
          ),
        ),
        if (showDivider) ...[
          const SizedBox(height: 4),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildEmergencyContact(String title, String number, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
            color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
        ),
            child: IconButton(
          onPressed: () {
            // TODO: Implement phone call functionality
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.phone, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Calling $number...'),
                      ],
                    ),
                backgroundColor: color,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
              ),
            );
          },
              icon: const Icon(
            Icons.phone,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatisticsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Municipality Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Reports', '234'),
            _buildStatRow('Resolved Issues', '189'),
            _buildStatRow('Pending Issues', '32'),
            _buildStatRow('In Progress', '13'),
            const SizedBox(height: 16),
            Text(
              'Response Rate: 81%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 