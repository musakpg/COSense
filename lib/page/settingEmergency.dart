import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fypcosense/page/homePage.dart';

class EmergencySetupScreen extends StatefulWidget {
  const EmergencySetupScreen({Key? key}) : super(key: key);

  @override
  _EmergencySetupScreenState createState() => _EmergencySetupScreenState();
}

class _EmergencySetupScreenState extends State<EmergencySetupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initialize Firestore

  late List<TextEditingController> _emergencyNameControllers;
  late List<TextEditingController> _emergencyEmailControllers;

  @override
  void initState() {
    super.initState();
    _emergencyNameControllers = [];
    _emergencyEmailControllers = [];
    fetchEmergencyContact();
  }

  void fetchEmergencyContact() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userDocRef = _firestore.collection('users').doc(userId);

      DocumentSnapshot snapshot = await userDocRef.get();

      if (snapshot.exists) {
        List<dynamic>? emergencyContacts = snapshot.get('emergencyContacts');
        if (emergencyContacts != null) {
          for (var i = 0; i < emergencyContacts.length; i++) {
            var contact = emergencyContacts[i];
            var nameController = TextEditingController(text: contact['name']);
            var emailController = TextEditingController(text: contact['email']);
            setState(() {
              _emergencyNameControllers.add(nameController);
              _emergencyEmailControllers.add(emailController);
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching emergency contacts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Padding(
          padding: EdgeInsets.only(left: 180.0),
          child: Text(
            'Emergency Contacts Settings',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _emergencyNameControllers.length,
                itemBuilder: (context, index) {
                  return _buildContactContainer(index);
                },
              ),
            ),
            _buildAddContactButton(),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                saveEmergencyContacts(); // Call function to save emergency contacts
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

  Widget _buildContactContainer(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0), // Increase the vertical padding for more spacing
      child: Material(
        elevation: 5.0, // Adjust the elevation as needed
        shadowColor: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10.0), // Ensure the border radius matches
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            color: Colors.white, // Ensure the background color is white or desired color
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact ${index + 1}'),
              const SizedBox(height: 10.0),
              TextFormField(
                controller: _emergencyNameControllers[index],
                decoration: InputDecoration(
                  labelText: 'Name',
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
              TextFormField(
                controller: _emergencyEmailControllers[index],
                decoration: InputDecoration(
                  labelText: 'Email',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      _deleteContact(index);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildAddContactButton() {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          var nameController = TextEditingController();
          var emailController = TextEditingController();
          _emergencyNameControllers.add(nameController);
          _emergencyEmailControllers.add(emailController);
        });
      },
      child: const Text(
          'Add another contact',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 5.0,
      ),
    );
  }

  void _deleteContact(int index) {
    setState(() {
      _emergencyNameControllers.removeAt(index);
      _emergencyEmailControllers.removeAt(index);
    });
  }

  void saveEmergencyContacts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid; // Get the user ID
      final userDocRef = _firestore.collection('users').doc(userId);

      List<Map<String, String>> contacts = [];
      for (int i = 0; i < _emergencyNameControllers.length; i++) {
        contacts.add({
          'name': _emergencyNameControllers[i].text,
          'email': _emergencyEmailControllers[i].text,
        });
      }

      // Update the user document with the new emergency contacts
      await userDocRef.update({
        'emergencyContacts': contacts,
      });

      // Show success message or navigate to another screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency contacts saved successfully!'),
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
      print('Error saving emergency contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving emergency contacts.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}