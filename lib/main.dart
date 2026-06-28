import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'home/no_internet_view.dart';

import 'home/splash_screen.dart';

late SupabaseClient supabase;
SharedPreferences? _prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAqRR1J4HNTQ1oNMhpsn6y89Hi10O9P17w",
        appId: "1:786560188458:web:9004e7227233baf5a2c353",
        messagingSenderId: "786560188458",
        projectId: "vet-app-80a7a",
        storageBucket: "vet-app-80a7a.firebasestorage.app",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  _prefs = await SharedPreferences.getInstance();

  supabase = SupabaseClient(
    'https://uwhkufxuixhdusjojhfw.supabase.co',
    'sb_publishable_EDi7VysIXSiZhnpjJjYOGQ_Vgop7WUd',
  );

  String language = _prefs?.getString('language') ?? 'ar';
  int colorValue = _prefs?.getInt('themeColor') ?? const Color(0xFFFDF9F5).value;

  String? initialPetId;
  if (kIsWeb) {
    final uri = Uri.base;
    if (uri.fragment.contains('/pet/')) {
      initialPetId = uri.fragment.split('/pet/').last;
    } else if (uri.path.contains('/pet/')) {
      initialPetId = uri.path.split('/pet/').last;
    }
    if (initialPetId != null && initialPetId!.contains('?')) {
      initialPetId = initialPetId!.split('?').first;
    }
  }

  runApp(MyApp(
    initialLocale: Locale(language),
    initialColor: Color(colorValue),
    startPetId: initialPetId,
  ));
}

class MyApp extends StatefulWidget {
  final Locale initialLocale;
  final Color initialColor;
  final String? startPetId;

  const MyApp({super.key, required this.initialLocale, required this.initialColor, this.startPetId});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  late Locale locale;
  late Color themeColor;

  @override
  void initState() {
    super.initState();
    locale = widget.initialLocale;
    themeColor = widget.initialColor;
  }

  void setLocale(Locale newLocale) => setState(() => locale = newLocale);
  void setThemeColor(Color color) => setState(() => themeColor = color);

  @override
  Widget build(BuildContext context) {
    bool isDark = themeColor.value == const Color(0xFF2D2D2D).value;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QPet',
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', ''), Locale('en', '')],
      theme: ThemeData(
        primaryColor: const Color(0xFF004040),
        scaffoldBackgroundColor: themeColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF004040),
          primary: const Color(0xFF004040),
          secondary: const Color(0xFFC5A059),
          surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        ),
        useMaterial3: true,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black87),
          bodyMedium: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
      ),
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },
      home: widget.startPetId != null 
          ? PublicPetProfilePage(petId: widget.startPetId!) 
          : const SplashScreen(),
    );
  }
}

class PublicPetProfilePage extends StatelessWidget {
  final String petId;
  const PublicPetProfilePage({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('pets').doc(petId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(isAr ? 'خطأ في التحميل' : 'Error Loading'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text(isAr ? 'الأليف غير موجود' : 'Pet Not Found'));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final color = Theme.of(context).primaryColor;
          final String? ownerUid = data['ownerUid'];

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const SplashScreen())),
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(isAr ? 'فتح التطبيق' : 'Open App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFF8F9FB),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Center(
                child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      width: double.infinity,
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
                      child: Icon(Icons.pets, color: color, size: 100),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(data['animalName'] ?? '', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _info(isAr ? 'النوع' : 'Type', data['animalType'], Icons.category, color),
                          _info(isAr ? 'الجنس' : 'Gender', data['gender'], Icons.transgender, color),
                          _info(isAr ? 'معقم / مخصي' : 'Neutered/Spayed', data['sterilizationStatus'], Icons.content_cut, color),
                          
                          const Divider(height: 40),
                          _info(isAr ? 'المالك' : 'Owner', data['ownerName'], Icons.person, color),
                          
                          if (ownerUid != null)
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').doc(ownerUid).snapshots(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
                                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                
                                bool hasFacebook = userData['facebook'] != null && userData['facebook'].toString().isNotEmpty;
                                bool hasTelegram = userData['telegram'] != null && userData['telegram'].toString().isNotEmpty;
                                bool hasWhatsapp = userData['whatsapp'] != null && userData['whatsapp'].toString().isNotEmpty;

                                if (!hasFacebook && !hasTelegram && !hasWhatsapp) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (hasFacebook) _socialIcon(Icons.facebook, userData['facebook'], Colors.blue),
                                      if (hasFacebook && (hasTelegram || hasWhatsapp)) const SizedBox(width: 15),
                                      if (hasTelegram) _socialIcon(Icons.telegram, userData['telegram'], Colors.lightBlue),
                                      if (hasTelegram && hasWhatsapp) const SizedBox(width: 15),
                                      if (hasWhatsapp) _socialIcon(null, 'https://wa.me/${userData['whatsapp']}', Colors.green, isWhatsApp: true),
                                    ],
                                  ),
                                );
                              },
                            ),

                          _info(isAr ? 'رقم التواصل' : 'Contact', data['ownerPhone'], Icons.phone, color),
                          const SizedBox(height: 20),
                          if (data['ownerPhone'] != null && data['ownerPhone'].toString().isNotEmpty) 
                            ElevatedButton.icon(
                              onPressed: () => _launchUrl('tel:${data['ownerPhone']}'),
                              icon: const Icon(Icons.call),
                              label: Text(isAr ? 'اتصل بالمالك الآن' : 'Call Owner Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                foregroundColor: Colors.white, 
                                minimumSize: const Size(double.infinity, 55), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                              ),
                            ),
                          
                          const Divider(height: 40),
                          Align(alignment: isAr ? Alignment.centerRight : Alignment.centerLeft, child: Text(isAr ? 'السجل الطبي' : 'Medical Record', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                          const SizedBox(height: 15),
                          _medInfo(isAr ? 'الوزن' : 'Weight', '${data['weight'] ?? '--'} kg'),
                          _medInfo(isAr ? 'العمر' : 'Age', data['age']),
                          
                          if (data['deworming_list'] != null && (data['deworming_list'] as List).isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Align(alignment: isAr ? Alignment.centerRight : Alignment.centerLeft, child: Text(isAr ? 'أحدث جرعات الديدان:' : 'Latest Deworming Doses:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown))),
                            const SizedBox(height: 10),
                            ...(data['deworming_list'] as List).reversed.take(2).map((e) => _medInfo(e['name'] ?? '', e['date'] ?? '')),
                          ],
                          
                          const SizedBox(height: 40),
                          const Text('QPet Team - Smart ID System', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ));
        },
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Widget _info(String l, String? v, IconData i, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8), 
    child: Row(children: [Icon(i, size: 22, color: c), const SizedBox(width: 12), Text(l), const Spacer(), Text(v ?? '--', style: const TextStyle(fontWeight: FontWeight.bold))])
  );

  Widget _medInfo(String l, String? v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4), 
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v ?? '--', style: const TextStyle(fontWeight: FontWeight.bold))])
  );

  Widget _socialIcon(IconData? icon, String url, Color color, {bool isWhatsApp = false}) => InkWell(
    onTap: () => _launchUrl(url),
    child: CircleAvatar(
      radius: 22, 
      backgroundColor: color.withOpacity(0.1), 
      child: isWhatsApp 
        ? SvgPicture.asset('assets/WhatsApp.svg', width: 24, height: 24)
        : Icon(icon, color: color, size: 24)
    ),
  );
}

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // إذا لم يوجد أي نوع من أنواع الاتصال في القائمة، نعتبر الجهاز أوفلاين
    final bool offline = results.every((result) => result == ConnectivityResult.none);
    if (_isOffline != offline) {
      setState(() => _isOffline = offline);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return NoInternetView(onRetry: _checkInitialConnectivity);
    }
    return widget.child;
  }
}
