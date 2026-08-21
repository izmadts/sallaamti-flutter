import 'package:flutter/material.dart';

// A TextFormField with a show/hide eye toggle — used everywhere a password
// is typed (login, register, register-confirm) so nobody has to type a
// password blind with no way to check what they entered.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? errorText;
  final String? Function(String?)? validator;
  // Lets the OS password manager recognize this field — pass
  // AutofillHints.password for login, AutofillHints.newPassword for
  // register (so it offers to *generate/save* rather than fill).
  final Iterable<String>? autofillHints;

  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.errorText,
    this.validator,
    this.autofillHints,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.labelText,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          icon: Icon(_obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: _obscured ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      validator: widget.validator,
    );
  }
}
