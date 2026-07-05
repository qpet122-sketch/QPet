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
        apiKey: "AIzaSyBfPupEnaEgFK7tYX6OswPXfYBjgRyiu3Y",
        appId: "1:582369930164:web:19cce1238f4c65954fa0e1",
        messagingSenderId: "582369930164",
        projectId: "qpet-edcb0",
        storageBucket: "qpet-edcb0.firebasestorage.app",
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

  // اللغة الافتراضية إنجليزية
  String language = _prefs?.getString('language') ?? 'en';
  int colorValue = _prefs?.getInt('themeColor') ?? const Color(0xFFFDF9F5).value;

  String? initialPetId;
  String? redirectDownload;

  if (kIsWeb) {
    final uri = Uri.base;
    final fragment = uri.fragment.toLowerCase();
    
    // التحقق من طلب التحميل بشكل أكثر مرونة
    if (fragment == '/download' || fragment == 'download' || uri.path.endsWith('/download')) {
      redirectDownload = 'pending';
    }

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
    shouldRedirectDownload: redirectDownload != null,
  ));
}

class MyApp extends StatefulWidget {
  final Locale initialLocale;
  final Color initialColor;
  final String? startPetId;
  final bool shouldRedirectDownload;

  const MyApp({
    super.key, 
    required this.initialLocale, 
    required this.initialColor, 
    this.startPetId,
    this.shouldRedirectDownload = false,
  });

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  late Locale locale;
  late Color themeColor;
  bool showPublicProfile = false;
  bool isRedirecting = false;

  @override
  void initState() {
    super.initState();
    locale = widget.initialLocale;
    themeColor = widget.initialColor;
    showPublicProfile = widget.startPetId != null;

    if (widget.shouldRedirectDownload) {
      _handleDownloadRedirect();
    }
  }

  Future<void> _handleDownloadRedirect() async {
    setState(() => isRedirecting = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('contact_info').get();
      if (doc.exists) {
        final url = doc.data()?['appDownloadUrl'];
        if (url != null && url.toString().isNotEmpty) {
          // محاولة التوجيه التلقائي
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      debugPrint("Redirect failed: $e");
    }
    // ملاحظة: المتصفحات قد تمنع التوجيه التلقائي بدون حركة من المستخدم
    // لذا سنترك صفحة التوجيه مفتوحة مع زر يدوي
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
      ),
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },
           home: isRedirecting 
          ? const DownloadRedirectPage()
          : (showPublicProfile 
              ? PublicPetProfilePage(petId: widget.startPetId!, onOpenApp: enterApp) 
              : const SplashScreen()),
    );
  }
}

class DownloadRedirectPage extends StatefulWidget {
  const DownloadRedirectPage({super.key});

  @override
  State<DownloadRedirectPage> createState() => _DownloadRedirectPageState();
}

class _DownloadRedirectPageState extends State<DownloadRedirectPage> {
  String? downloadUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndRedirect();
  }

  Future<void> _fetchAndRedirect() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('contact_info').get();
      if (doc.exists && mounted) {
        final url = doc.data()?['appDownloadUrl'];
        if (url != null && url.toString().isNotEmpty) {
          setState(() {
            downloadUrl = url;
            isLoading = false;
          });
          // محاولة بدء التحميل تلقائياً
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/final_logo-Photoroom.png', height: 120),
              const SizedBox(height: 40),
              if (isLoading)
                const CircularProgressIndicator(color: Color(0xFFC5A059))
              else ...[
                Icon(Icons.cloud_download_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                Text(
                  isAr ? 'جاري بدء التحميل...' : 'Starting download...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  isAr 
                    ? 'إذا لم يبدأ التحميل خلال ثوانٍ، اضغط على الزر أدناه' 
                    : 'If download doesn\'t start, please click the button below',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 30),
                if (downloadUrl != null)
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(downloadUrl!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.download),
                    label: Text(isAr ? 'بدء التحميل الآن' : 'Start Download Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004040),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(250, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                  ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SplashScreen())
                  ),
                  child: Text(isAr ? 'الاستمرار في نسخة الويب' : 'Continue to Web App'),
                ),
              ],
            ],
          ),
        ),
      ),
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
              icon: const Icon(Icons.apps_rounded, size: 18),
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
                            child: const Text('Smart ID System', style: TextStyle(color: royalGold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
                                bool hasInstagram = userData['instagram'] != null && userData['instagram'].toString().isNotEmpty;
                                bool hasTelegram = userData['telegram'] != null && userData['telegram'].toString().isNotEmpty;
                                bool hasWhatsapp = userData['whatsapp'] != null && userData['whatsapp'].toString().isNotEmpty;
                                if (!hasFacebook && !hasInstagram && !hasTelegram && !hasWhatsapp) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (hasFacebook) _socialIcon(Icons.facebook, userData['facebook'], Colors.blue),
                                      if (hasFacebook && (hasInstagram || hasTelegram || hasWhatsapp)) const SizedBox(width: 15),
                                      if (hasInstagram) _socialIcon(null, userData['instagram'], Colors.purple, imagePath: 'assets/insta.png'),
                                      if (hasInstagram && (hasTelegram || hasWhatsapp)) const SizedBox(width: 15),
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

  Widget _socialIcon(IconData? icon, String url, Color color, {bool isWhatsApp = false, String? imagePath}) {
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
        child: Padding(
          padding: const EdgeInsets.all(8.0), // إضافة Padding لتحسين شكل الصورة
          child: isWhatsApp 
            ? SvgPicture.asset('assets/WhatsApp.svg')
            : (imagePath != null 
                ? Image.asset(imagePath, fit: BoxFit.contain)
                : Icon(icon, color: color, size: 24)),
        )
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
