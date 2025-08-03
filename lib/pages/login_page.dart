import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[350],
      body: Padding(
        padding: const EdgeInsets.only(top: 11.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Logo
              Container(
                  child: Lottie.asset('assets/animations/login_animation.json',)),

              //short description
              Text("Room khojdai ho?",
              style: TextStyle(
                  fontSize: 25,
                  color: Colors.black,
                  fontWeight: FontWeight.bold
              ),
              ),
              // login prompt
              Text("Basobaas cha ni!",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                ),),
              SizedBox(height: 20),
              //username or Email
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)
                  ),
                    child:  Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Email",
                          border: InputBorder.none
                        ),
                      ),
                    ),
                ),
              ),

              SizedBox(height: 15),
              //password
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child:  Padding(
                    padding: const EdgeInsets.only(left: 15.0),
                    child: TextField(
                      decoration: InputDecoration(
                          hintText: "Password",
                          border: InputBorder.none
                      ),
                    ),
                  ),
                ),
              ),
              //login/ --> register
              SizedBox(height: 20,),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Center(
                    child: Text("Sign in",
                    style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Not a Member?"),
                  Text(" Sign up!",
                  style: TextStyle(color: Colors.blue),)
                ],
              ),
              // continue with google!

            ],
          ),
        ),
      ),
    );
  }
}
