import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';

/// Widget for selecting municipality from dropdown
class MunicipalitySelector extends StatefulWidget {
  const MunicipalitySelector({super.key});

  @override
  State<MunicipalitySelector> createState() => _MunicipalitySelectorState();
}

class _MunicipalitySelectorState extends State<MunicipalitySelector> {
  List<Map<String, dynamic>> _municipalities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('🏙️ Municipality selector initializing...');
    _loadMunicipalities();
  }

  Future<void> _loadMunicipalities() async {
    print('🏙️ Loading municipalities...');
    final locationService = Provider.of<LocationService>(context, listen: false);
    try {
      final municipalities = await locationService.getAllMunicipalities();
      print('🏙️ Loaded ${municipalities.length} municipalities');
      
      if (mounted) {
        setState(() {
          _municipalities = municipalities;
          _isLoading = false;
          _error = null;
        });
        print('🏙️ Municipality selector state updated');
      }
    } catch (e) {
      print('🏙️ Error loading municipalities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        // Loading state
        if (_isLoading) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading municipalities...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Error state
        if (_error != null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load municipalities',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadMunicipalities();
                  },
                  child: const Text('Retry', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          );
        }

        // Find the selected municipality in the list
        final selectedMunicipality = appState.selectedMunicipality;
        final hasValidSelection = selectedMunicipality != null && 
            _municipalities.any((m) => m['name'] == selectedMunicipality);

        print('🏙️ Selected municipality: $selectedMunicipality');
        print('🏙️ Has valid selection: $hasValidSelection');
        print('🏙️ Available municipalities: ${_municipalities.map((m) => m['name']).toList()}');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simplified dropdown
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: hasValidSelection 
                    ? Theme.of(context).primaryColor.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.3),
                  width: hasValidSelection ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: hasValidSelection 
                  ? Theme.of(context).primaryColor.withOpacity(0.05)
                  : Colors.white,
              ),
              child: DropdownButtonFormField<String>(
                value: hasValidSelection ? selectedMunicipality : null,
                decoration: InputDecoration(
                  hintText: 'Choose your municipality',
                  prefixIcon: Icon(
                    Icons.location_city, 
                    color: hasValidSelection 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey,
                    size: 20,
                  ),
                  suffixIcon: hasValidSelection 
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 18,
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                items: _municipalities.map((municipality) {
                  final name = municipality['name'] as String;
                  
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    print('🏙️ Municipality manually selected: $value');
                    appState.setMunicipality(value);
                  }
                },
                isExpanded: true,
                menuMaxHeight: 300,
                dropdownColor: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                ),
              ),
            ),

            // Minimal help text
            if (!hasValidSelection) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Select your municipality to enable reporting',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
} 