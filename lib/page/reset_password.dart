import 'package:flutter/material.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'set a new password',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18.0),
            ),
            const TextField(
              decoration: InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            const SizedBox(height: 10.0),
            const TextField(
              decoration: InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                // Implement password reset logic here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset successfully!'),
                  ),
                );
                // Navigate back to sign in screen
                Navigator.pop(context);
              },
              child: const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}