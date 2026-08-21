import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/step_wizard_scaffold.dart';
import '../../state/nikah_controller.dart';
import 'nikah_step1_screen.dart' show maritalStatusOptions;

class NikahStep3Screen extends ConsumerStatefulWidget {
  const NikahStep3Screen({super.key});

  @override
  ConsumerState<NikahStep3Screen> createState() => _NikahStep3ScreenState();
}

class _NikahStep3ScreenState extends ConsumerState<NikahStep3Screen> {
  final _aboutController = TextEditingController();
  final _expectationsController = TextEditingController();
  final _prefMinAgeController = TextEditingController();
  final _prefMaxAgeController = TextEditingController();
  final _prefCityController = TextEditingController();
  final _prefSectController = TextEditingController();
  final _prefEducationController = TextEditingController();
  String? _prefMaritalStatus;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(nikahControllerProvider).profile;
    if (profile != null) {
      _aboutController.text = profile.about ?? '';
      _expectationsController.text = profile.expectations ?? '';
      _prefMinAgeController.text = profile.prefMinAge?.toString() ?? '';
      _prefMaxAgeController.text = profile.prefMaxAge?.toString() ?? '';
      _prefCityController.text = profile.prefCity ?? '';
      _prefSectController.text = profile.prefSect ?? '';
      _prefEducationController.text = profile.prefEducation ?? '';
      _prefMaritalStatus = profile.prefMaritalStatus;
    }
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _expectationsController.dispose();
    _prefMinAgeController.dispose();
    _prefMaxAgeController.dispose();
    _prefCityController.dispose();
    _prefSectController.dispose();
    _prefEducationController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(nikahControllerProvider.notifier).save({
        'about': _aboutController.text.trim(),
        'expectations': _expectationsController.text.trim(),
        'pref_min_age': _prefMinAgeController.text.trim(),
        'pref_max_age': _prefMaxAgeController.text.trim(),
        'pref_city': _prefCityController.text.trim(),
        'pref_sect': _prefSectController.text.trim(),
        'pref_education': _prefEducationController.text.trim(),
        'pref_marital_status': _prefMaritalStatus,
      });
      if (mounted) context.push('/nikah/wizard/step4');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StepWizardScaffold(
      title: 'About & Preferences',
      stepIndex: 2,
      totalSteps: 5,
      nextLabel: 'Next: Photos & Verification',
      onNext: _next,
      busy: _busy,
      errorText: _error,
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('In your own words', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _aboutController,
            decoration: const InputDecoration(labelText: 'About yourself (optional)'),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _expectationsController,
            decoration: const InputDecoration(labelText: 'What are you looking for? (optional)'),
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          const Text('Partner Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Used to show your match % with other profiles.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _prefMinAgeController,
                  decoration: const InputDecoration(labelText: 'Min age'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _prefMaxAgeController,
                  decoration: const InputDecoration(labelText: 'Max age'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _prefCityController, decoration: const InputDecoration(labelText: 'Preferred city (optional)')),
          const SizedBox(height: 16),
          TextFormField(controller: _prefSectController, decoration: const InputDecoration(labelText: 'Preferred sect (optional)')),
          const SizedBox(height: 16),
          TextFormField(controller: _prefEducationController, decoration: const InputDecoration(labelText: 'Preferred education (optional)')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _prefMaritalStatus,
            decoration: const InputDecoration(labelText: 'Preferred marital status (optional)'),
            items: maritalStatusOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _prefMaritalStatus = v),
          ),
        ],
      ),
    );
  }
}
