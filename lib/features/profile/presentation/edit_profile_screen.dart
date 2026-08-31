import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/authed_avatar.dart';
import '../../auth/state/auth_controller.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _nameController = TextEditingController(text: ref.read(authControllerProvider).user?.name ?? '');
  late final _emailController = TextEditingController(text: ref.read(authControllerProvider).user?.email ?? '');
  late final _phoneController = TextEditingController(text: ref.read(authControllerProvider).user?.phone ?? '');
  late final _cityController = TextEditingController(text: ref.read(authControllerProvider).user?.city ?? '');
  String? _gender;
  File? _newAvatar;

  bool _savingProfile = false;
  String? _profileError;

  bool _nikah = true;
  bool _quran = true;
  bool _counseling = true;
  bool _skills = true;
  bool _savingModules = false;
  String? _modulesError;
  bool _modulesInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _initModulesOnce() {
    if (_modulesInitialized) return;
    final modules = ref.read(authControllerProvider).user?.modules ?? {};
    _nikah = modules['nikah'] ?? true;
    _quran = modules['quran'] ?? true;
    _counseling = modules['counseling'] ?? true;
    _skills = modules['skills'] ?? true;
    _modulesInitialized = true;
  }

  @override
  void initState() {
    super.initState();
    _gender = ref.read(authControllerProvider).user?.gender;
    _initModulesOnce();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _newAvatar = File(picked.path));
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _profileError = 'Please enter your name.');
      return;
    }

    setState(() {
      _savingProfile = true;
      _profileError = null;
    });

    try {
      final updated = await ref.read(profileRepositoryProvider).update(
            name: _nameController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            gender: _gender,
            city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
            avatar: _newAvatar,
          );
      ref.read(authControllerProvider.notifier).setUser(updated);
      if (mounted) {
        setState(() => _newAvatar = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } on ApiException catch (e) {
      setState(() => _profileError = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _profileError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveModules() async {
    setState(() {
      _savingModules = true;
      _modulesError = null;
    });

    try {
      final updated = await ref.read(profileRepositoryProvider).updateModules(
            nikah: _nikah,
            quran: _quran,
            counseling: _counseling,
            skills: _skills,
          );
      ref.read(authControllerProvider.notifier).setUser(updated);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modules updated.')));
    } on ApiException catch (e) {
      setState(() => _modulesError = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _modulesError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _savingModules = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  if (_newAvatar != null)
                    CircleAvatar(radius: 48, backgroundColor: Colors.teal.withValues(alpha: 0.1), backgroundImage: FileImage(_newAvatar!))
                  else
                    AuthedAvatar(
                      url: user?.avatarUrl,
                      radius: 48,
                      backgroundColor: Colors.teal.withValues(alpha: 0.1),
                      fallback: const Icon(Icons.person, size: 40),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: _pickAvatar,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Profile Information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 16),
                    if (_profileError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Text(_profileError!, style: TextStyle(color: Colors.red.shade700)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 12),
                    TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _savingProfile ? null : _saveProfile,
                      child: _savingProfile
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Profile'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Module Visibility', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      'Turn off anything you\'re not using — it disappears from your dashboard, your data stays safe either way.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (_modulesError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Text(_modulesError!, style: TextStyle(color: Colors.red.shade700)),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('💍 Nikah Matchmaking'),
                      value: _nikah,
                      onChanged: (v) => setState(() => _nikah = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('📖 Quran Learning'),
                      value: _quran,
                      onChanged: (v) => setState(() => _quran = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('🤝 Family Counseling'),
                      value: _counseling,
                      onChanged: (v) => setState(() => _counseling = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('💻 Digital Skills'),
                      value: _skills,
                      onChanged: (v) => setState(() => _skills = v),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _savingModules ? null : _saveModules,
                      child: _savingModules
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Modules'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
