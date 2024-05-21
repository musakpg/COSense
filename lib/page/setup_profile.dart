import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fypcosense/page/setup_emergency.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10.0),
            TextFormField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10.0),
            ElevatedButton(
              onPressed: () {
                saveProfileData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void saveProfileData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid; // Get the user ID
      final userDocRef = _firestore.collection('users').doc(userId);

      // Add the user's name and phone number
      final profileData ={
        'name': _nameController.text,
        'phoneNumber': _phoneNumberController.text,
      };

      await userDocRef.set({
        'profile': profileData,
      });
      // Show a success message or navigate to another screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      // Navigate to setup_emergency screen after the snackbar disappears
      // (assuming you have a navigation function or a route defined)
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EmergencySetupScreen(),
          ),
        );
      });
    } catch (e) {
      // Handle any errors
      print('Error saving profile data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile data.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
