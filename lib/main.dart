import 'package:basobaas_map/pages/base_page.dart';
import 'package:basobaas_map/pages/login/login_page.dart';
import 'package:basobaas_map/provider/auth_provider.dart';
import 'package:basobaas_map/provider/post_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://cccljhxlvmizkugxgoxi.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNjY2xqaHhsdm1pemt1Z3hnb3hpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0NDE0OTcsImV4cCI6MjA3MTAxNzQ5N30.u_q84qxeVX5kxdVqjFXSpx2azDlXqtaY5A25zix-YLU',
  );
  final supabaseServiceClient = SupabaseClient(
    'https://cccljhxlvmizkugxgoxi.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNjY2xqaHhsdm1pemt1Z3hnb3hpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTQ0MTQ5NywiZXhwIjoyMDcxMDE3NDk3fQ.7On6QtM6GMg-g2ae2ift6OrJ0BkLy69TMWelaK82JEg', // <-- replace this with your service role key
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider(supabaseServiceClient)),
      ],
    child: const MyApp(),
  ),);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return auth.user == null ? const LoginPage() : const MainPage();
          },
        )
    );
  }
}