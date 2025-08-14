import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  String description = '';
  String price = '';
  XFile? image;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? pickedImage =
    await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        image = pickedImage;
      });
    }
  }

  void submitPost() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // TODO: Send data to Firebase Firestore/Storage
      debugPrint("Title: $title, Desc: $description, Price: $price, Image: ${image?.path}");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your listing has been submitted!")),
      );

      // Clear form
      setState(() {
        title = '';
        description = '';
        price = '';
        image = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post a Room/Flat"),
        backgroundColor: Colors.deepPurple[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image picker
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey),
                    image: image != null
                        ? DecorationImage(
                      image: FileImage(File(image!.path)),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: image == null
                      ? const Center(
                    child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? "Enter a title" : null,
                onSaved: (value) => title = value!.trim(),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? "Enter a description" : null,
                onSaved: (value) => description = value!.trim(),
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Price (per month)",
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? "Enter a price" : null,
                onSaved: (value) => price = value!.trim(),
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Post Listing",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
