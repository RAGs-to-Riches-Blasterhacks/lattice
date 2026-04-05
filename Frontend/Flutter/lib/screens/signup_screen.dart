import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lattice/navigation/app_navigation.dart';
import 'package:lattice/providers/auth_provider.dart';
import 'package:lattice/services/api_service.dart';
import 'package:lattice/themes/app_colors.dart';
import 'package:provider/provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedTimezone;
  String? _selectedLocation;
  List<String> _locationSuggestions = [];
  bool _loading = false;
  String? _error;

  static const List<String> _timezones = [
    'UTC',
    'EST (Eastern Standard)',
    'CST (Central Standard)',
    'MST (Mountain Standard)',
    'PST (Pacific Standard)',
    'GMT (Greenwich Mean)',
    'CET (Central European)',
    'IST (Indian Standard)',
    'JST (Japan Standard)',
    'AEST (Australian Eastern)',
  ];

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final timezone = _selectedTimezone;

    if (displayName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        timezone == null) {
      setState(() => _error = 'All required fields must be filled');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      await auth.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (mounted) {
        await AppNavigation.goToHome(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.whileInUse ||
            result == LocationPermission.always) {
          // Permission granted, fetch location
          await _fetchLocationSuggestions();
        } else if (result == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else if (status == LocationPermission.whileInUse ||
          status == LocationPermission.always) {
        // Already granted, fetch location
        await _fetchLocationSuggestions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting location: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _fetchLocationSuggestions() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final suggestions = <String>{};
        for (final placemark in placemarks) {
          // Build location strings from different combinations
          final parts = <String>[];
          if (placemark.locality != null && placemark.locality!.isNotEmpty) {
            parts.add(placemark.locality!);
          }
          if (placemark.administrativeArea != null &&
              placemark.administrativeArea!.isNotEmpty) {
            parts.add(placemark.administrativeArea!);
          }
          if (placemark.country != null && placemark.country!.isNotEmpty) {
            parts.add(placemark.country!);
          }

          if (parts.isNotEmpty) {
            suggestions.add(parts.join(', '));
          }
        }

        if (mounted) {
          setState(() {
            _locationSuggestions = suggestions.toList();
            if (_locationSuggestions.isNotEmpty) {
              _selectedLocation = _locationSuggestions.first;
            }
          });
          if (_locationSuggestions.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location updated'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching location: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => AppNavigation.goToLanding(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.gradientBackground),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              Image.asset('assets/LOGO.png', width: 140),
              const SizedBox(height: 32),
              Text(
                'Create Your Account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start building your personalized learning plans',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              _buildField(_displayNameController, 'Display Name'),
              const SizedBox(height: 12),
              _buildField(_emailController, 'Email',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildField(_passwordController, 'Password', obscure: true),
              const SizedBox(height: 12),
              _buildField(_confirmPasswordController, 'Confirm Password',
                  obscure: true),
              const SizedBox(height: 12),
              _buildTimezoneDropdown(),
              const SizedBox(height: 12),
              _locationSuggestions.isEmpty
                  ? _buildField(_locationController, 'Location (Optional)',
                      isOptional: true)
                  : _buildLocationDropdown(),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.secondary,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => AppNavigation.goToLogin(context),
                child: const Text(
                  'Already have an account? Log in',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        ),
        ],
      ),
    );
  }

  Widget _buildTimezoneDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedTimezone,
      decoration: InputDecoration(
        hintText: 'Select Timezone',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
      dropdownColor: AppColors.cardBackground,
      items: _timezones
          .map((tz) => DropdownMenuItem(
                value: tz,
                child: Text(
                  tz,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ))
          .toList(),
      onChanged: (value) => setState(() => _selectedTimezone = value),
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedLocation,
      decoration: InputDecoration(
        hintText: 'Select or enter location',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
      dropdownColor: AppColors.cardBackground,
      items: _locationSuggestions
          .map((location) => DropdownMenuItem(
                value: location,
                child: Text(
                  location,
                  style: const TextStyle(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (value) => setState(() => _selectedLocation = value),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    bool isOptional = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      cursorColor: AppColors.textPrimary,
      style: const TextStyle(color: AppColors.textPrimary),
      onTap: isOptional && hint == 'Location (Optional)'
          ? _requestLocationPermission
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}
