import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingProfile extends StatefulWidget {
  const SettingProfile({Key? key}) : super(key: key);

  @override
  _SettingProfileState createState() => _SettingProfileState();
}

class _SettingProfileState extends State<SettingProfile> {
  late TextEditingController _nameController;
  late TextEditingController _phoneNumberController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneNumberController = TextEditingController();
    fetchProfileData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Material(
              elevation: 5.0,
              shadowColor: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                ),
                child: Column(
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
                  ],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                saveProfileData();
              },
              child: const Text('Save'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 100, vertical: 15), // Adjust the padding as needed
              ),
            ),
          ],
        ),
      ),
    );
  }

  void fetchProfileData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userDocRef = _firestore.collection('users').doc(userId);

      DocumentSnapshot snapshot = await userDocRef.get();

      if (snapshot.exists) {
        Map<String, dynamic>? profileData = snapshot.get('profile');
        if (profileData != null) {
          setState(() {
            _nameController.text = profileData['name'] ?? '';
            _phoneNumberController.text = profileData['phoneNumber'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error fetching profile data: $e');
    }
  }

  void saveProfileData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userDocRef = _firestore.collection('users').doc(userId);

      final profileData = {
        'name': _nameController.text,
        'phoneNumber': _phoneNumberController.text,
      };

      await userDocRef.update({
        'profile': profileData,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving profile data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile data.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }
}
