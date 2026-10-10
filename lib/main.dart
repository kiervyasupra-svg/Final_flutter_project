import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/data_seeder.dart';
import 'features/admin/presentation/screens/admin_home_screen.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/customer/presentation/controllers/booking_controller.dart';
import 'features/customer/presentation/controllers/store_controller.dart';
import 'features/customer/presentation/screens/customer_home_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await DataSeeder.seedInitialData();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Firebase Core',
        context:
            ErrorDescription('Failed to initialize Firebase for WASHMATE.'),
      ),
    );
  }

  runApp(const WashMateApp());
}

class WashMateApp extends StatelessWidget {
  const WashMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(
            create: (_) => BookingController()..fetchServices()),
        ChangeNotifierProvider(create: (_) => StoreController()),
      ],
      child: MaterialApp(
        title: 'WASHMATE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.softTheme,
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (auth.errorMessage != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      auth.errorMessage ?? 'Please try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => auth.logout(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (auth.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your WASHMATE experience...'),
                ],
              ),
            ),
          );
        }

        if (auth.currentUser == null) {
          return const LoginScreen();
        }

        if (auth.currentUser?.role == 'admin') {
          return const AdminHomeScreen();
        }

        return const CustomerHomeScreen();
      },
    );
  }
}
