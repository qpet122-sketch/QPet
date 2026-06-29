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
  bool showPublicProfile = false;

  @override
  void initState() {
    super.initState();
    locale = widget.initialLocale;
    themeColor = widget.initialColor;
    showPublicProfile = widget.startPetId != null;
  }

  void setLocale(Locale newLocale) => setState(() => locale = newLocale);
  void setThemeColor(Color color) => setState(() => themeColor = color);
  void enterApp() => setState(() => showPublicProfile = false);

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
      home: showPublicProfile 
          ? PublicPetProfilePage(petId: widget.startPetId!, onOpenApp: enterApp) 
          : const SplashScreen(),
    );
  }
}

class PublicPetProfilePage extends StatelessWidget {
  final String petId;
  final VoidCallback onOpenApp;
  const PublicPetProfilePage({super.key, required this.petId, required this.onOpenApp});

  @override
  Widget build(BuildContext context) {
    bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    const Color primaryGreen = Color(0xFF004040);
    const Color royalGold = Color(0xFFC5A059);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF9F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Image.asset('assets/final_logo-Photoroom.png', height: 40),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: onOpenApp,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(isAr ? 'فتح التطبيق' : 'Open App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: royalGold, 
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('pets').doc(petId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(isAr ? 'خطأ في التحميل' : 'Error Loading'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: royalGold));
          if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text(isAr ? 'الأليف غير موجود' : 'Pet Not Found'));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String? ownerUid = data['ownerUid'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(35), 
                  boxShadow: [BoxShadow(color: royalGold.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))],
                  border: Border.all(color: royalGold.withOpacity(0.1), width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [royalGold.withOpacity(0.05), Colors.white],
                        ),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset('assets/final_logo-Photoroom.png', width: 120, height: 120, fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(20)),
                            child: Text('Smart ID System', style: TextStyle(color: royalGold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      child: Column(
                        children: [
                          Text(data['animalName'] ?? '', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryGreen)),
                          const SizedBox(height: 5),
                          Text(
                            '${data['animalType'] ?? ''}${data['animalBreed'] != null && data['animalBreed'].toString().isNotEmpty ? ' - ${data['animalBreed']}' : ''}', 
                            style: const TextStyle(fontSize: 18, color: royalGold, fontWeight: FontWeight.w500)
                          ),
                          
                          const SizedBox(height: 30),
                          _buildSectionTitle(isAr ? 'البيانات الأساسية' : 'Basic Information', royalGold),
                          _info(isAr ? 'الجنس' : 'Gender', data['gender'], Icons.transgender, royalGold),
                          _info(isAr ? 'معقم / مخصي' : 'Neutered/Spayed', data['sterilizationStatus'], Icons.content_cut, royalGold),
                          
                          const SizedBox(height: 25),
                          _buildSectionTitle(isAr ? 'بيانات المالك' : 'Owner Details', royalGold),
                          _info(isAr ? 'الاسم' : 'Owner', data['ownerName'], Icons.person_outline, royalGold),
                          
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
                                  padding: const EdgeInsets.symmetric(vertical: 10),
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

                          _info(isAr ? 'رقم التواصل' : 'Contact', data['ownerPhone'], Icons.phone_android_outlined, royalGold),
                          const SizedBox(height: 20),
                          if (data['ownerPhone'] != null && data['ownerPhone'].toString().isNotEmpty) 
                            ElevatedButton.icon(
                              onPressed: () => _launchUrl('tel:${data['ownerPhone']}'),
                              icon: const Icon(Icons.call_rounded),
                              label: Text(isAr ? 'اتصل بالمالك الآن' : 'Call Owner Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                foregroundColor: Colors.white, 
                                minimumSize: const Size(double.infinity, 60), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 5,
                                shadowColor: Colors.green.withOpacity(0.3),
                              ),
                            ),
                          
                          const SizedBox(height: 35),
                          _buildSectionTitle(isAr ? 'السجل الطبي' : 'Medical Record', royalGold),
                          _medInfo(isAr ? 'الوزن' : 'Weight', '${data['weight'] ?? '--'} kg'),
                          _medInfo(isAr ? 'العمر' : 'Age', data['age']),

                          _buildMedicalList(isAr ? 'التطعيمات' : 'Vaccinations', data['vaccinations_list'], (item) => '${item['type']} (${item['date']})${item['next'] != '' ? ' -> ${isAr ? 'القادمة' : 'Next'}: ${item['next']}' : ''}'),
                          _buildMedicalList(isAr ? 'العمليات الجراحية' : 'Surgeries', data['surgeries_list'], (item) => '${item['name']} (${item['date']})'),
                          _buildMedicalList(isAr ? 'الأدوية الحالية' : 'Current Medications', data['medications_list'], (item) => '${item['name']} - ${item['duration']}'),
                          _buildMedicalList(isAr ? 'جرعات الديدان' : 'Deworming Doses', data['deworming_list'], (item) => '${item['name']} (${item['date']})'),
                          
                          _buildSimpleMedicalList(isAr ? 'سجل الحساسية' : 'Allergies', data['allergies_list']),
                          _buildSimpleMedicalList(isAr ? 'الأمراض المزمنة' : 'Chronic Diseases', data['chronic_diseases_list']),
                          
                          const SizedBox(height: 50),
                          const Divider(),
                          const SizedBox(height: 15),
                          Text('QPet Team - Smart ID System', style: TextStyle(color: royalGold.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildMedicalList(String title, dynamic list, String Function(dynamic) labelBuilder) {
    if (list == null || (list as List).isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown)),
        const SizedBox(height: 8),
        ...(list as List).map((item) => _medInfo('', labelBuilder(item))),
      ],
    );
  }

  Widget _buildSimpleMedicalList(String title, dynamic list) {
    if (list == null || (list as List).isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
        const SizedBox(height: 8),
        ...(list as List).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            const Icon(Icons.circle, size: 6, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(item.toString(), style: const TextStyle(fontSize: 14))),
          ]),
        )),
      ],
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

  Widget _socialIcon(IconData? icon, String url, Color color, {bool isWhatsApp = false}) {
    String finalUrl = url;
    if (isWhatsApp) {
      String phone = url.split('wa.me/').last;
      if (phone.startsWith('0')) {
        phone = '2$phone';
      } else if (!phone.startsWith('2') && !phone.startsWith('+')) {
        phone = '2$phone';
      }
      finalUrl = 'https://wa.me/${phone.replaceAll(' ', '').replaceAll('+', '')}';
    }

    return InkWell(
      onTap: () => _launchUrl(finalUrl),
      child: CircleAvatar(
        radius: 22, 
        backgroundColor: color.withOpacity(0.1), 
        child: isWhatsApp 
          ? SvgPicture.asset('assets/WhatsApp.svg', width: 24, height: 24)
          : Icon(icon, color: color, size: 24)
      ),
    );
  }
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
