import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';  // <-- generated file
import 'services/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/error_handler.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/buyer/buyerDashboardScreen.dart';
import 'screens/seller/seller_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/branch_director/branch_director_dashboard_screen.dart';
import 'screens/finance/finance_dashboard_screen.dart';
import 'screens/technical/technical_dashboard_screen.dart';
import 'screens/corporate_sales/corporate_sales_dashboard_screen.dart';
import 'screens/showroom/showroom_dashboard_screen.dart';
import 'screens/business_staff/business_staff_dashboard_screen.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler (top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('📩 Background message: ${message.notification?.title}');
  // You can show a local notification here if needed
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService().initializeLocalNotifications();

  // ---- Global error handler ----
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FlutterError: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error');
    return true;
  };

  // ---- Initialize services ----
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');
  final role = await storage.read(key: 'user_role');

  // ✅ No polling started here; now relies on FCM updates
  // (NotificationService().startPolling() removed)

  Widget initialScreen;
  if (token != null && token.isNotEmpty) {
    switch (role) {
      case 'admin':
        initialScreen = const AdminDashboardScreen();
        break;
      case 'seller':
        initialScreen = const SellerDashboardScreen();
        break;
      case 'branch_director':
        initialScreen = const BranchDirectorDashboardScreen();
        break;
      case 'finance':
        initialScreen = const FinanceDashboardScreen();
        break;
      case 'technical':
        initialScreen = const TechnicalDashboardScreen();
        break;
      case 'corporate_sales':
        initialScreen = const CorporateSalesDashboardScreen();
        break;
      case 'showroom':
        initialScreen = const ShowroomDashboardScreen();
        break;
      case 'business_staff':
        initialScreen = const BusinessStaffDashboardScreen();
        break;
      default:
        initialScreen = const BuyerDashboardScreen();
        break;
    }
  } else {
    initialScreen = const WelcomeScreen();
  }

  // ---- Set logout callback for ErrorHandler ----
  ErrorHandler.setLogoutCallback(() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  });

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: WingaProApp(initialScreen: initialScreen),
    ),
  );
}

class WingaProApp extends StatefulWidget {
  final Widget initialScreen;
  const WingaProApp({super.key, required this.initialScreen});

  @override
  State<WingaProApp> createState() => _WingaProAppState();
}

class _WingaProAppState extends State<WingaProApp> {
  late ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _connectivityService = ConnectivityService();
    _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (!isConnected) {
        _showOfflineBanner(context);
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
  }

  void _showOfflineBanner(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 8),
            Text('You are offline. Please check your connection.'),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(days: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'WINGA PRO',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      home: widget.initialScreen,
      navigatorKey: navigatorKey,
    );
  }
}