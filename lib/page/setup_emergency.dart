import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fypcosense/page/homePage.dart';

class EmergencySetupScreen extends StatefulWidget {
  const EmergencySetupScreen({Key? key}) : super(key: key);

  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<EmergencySetupScreen> {
  final TextEditingController _emergencyNameController = TextEditingController();
  final TextEditingController _emergencyEmailController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initialize Firestore

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(left: 0.1),
          child: Text(
            'Setup Emergency Contact',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            TextFormField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10.0),
            TextFormField(
              controller: _emergencyEmailController,
              decoration: InputDecoration(
                labelText: 'Emergency Contact Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.blue,
                    width: 2.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.blue,
                    width: 2.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.blue,
                    width: 2.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            ElevatedButton(
              onPressed: () {
                saveEmergencyContact(); // Call function to save emergency contact
              },
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void saveEmergencyContact() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid; // Get the user ID
      // Create a reference to the document with the desired ID
      final userDocRef = _firestore.collection('users').doc(userId);

      final emergencyContact = {
        'name': _emergencyNameController.text,
        'email': _emergencyEmailController.text,
      };

      // Update the user document with the new emergency contact
      await userDocRef.update({
        'emergencyContacts': FieldValue.arrayUnion([emergencyContact]),
      });

      // Show success message or navigate to another screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency contact saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      // Navigate to home screen after the snackbar disappears
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(),
          ),
        );
      });
    } catch (e) {
      // Handle any errors
      print('Error saving emergency contact: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving emergency contact.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
