import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vet/main.dart';
import 'profile_edit_view.dart';
import 'pet_loading.dart'; // استيراد شكل التحميل
import 'login_view.dart';

class SettingsView extends StatefulWidget {
  final VoidCallback? onProfileUpdated; // إضافة Callback للتنبيه بالتحديث
  const SettingsView({super.key, this.onProfileUpdated});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final List<Color> themeColors = [
    const Color(0xffFDF9F5), // الذهبي الملكي
    const Color(0xFF2D2D2D), // لون غامق (رمادي فحم)
  ];

  Map<String, dynamic>? userData;
  Map<String, dynamic>? clinicContact; // إضافة متغير لبيانات العيادة
  String? userRole;
  bool _isLoading = true; // متغير حالة التحميل
  String? userName;
  String? userEmail;
  String? profileImageUrl;
  bool isUploading = false;

  // إعدادات Cloudinary - يجب استبدال هذه القيم ببيانات حسابك
  final cloudinary = CloudinaryPublic('dpgb9n7y1', 'qpet-app', cache: false);

  @override
  void initState() {
    super.initState();
    _initializeData(); // دمج كل طلبات البيانات في دالة واحدة
  }

  Future<void> _initializeData() async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      // جلب بيانات المستخدم وبيانات التواصل في نفس الوقت
      final results = await Future.wait([
        if (user != null) FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        FirebaseFirestore.instance.collection('config').doc('contact_info').get(),
      ]);

      if (mounted) {
        setState(() {
          // معالجة بيانات المستخدم
          if (user != null && results[0] is DocumentSnapshot) {
            final userDoc = results[0] as DocumentSnapshot;
            userData = userDoc.data() as Map<String, dynamic>?;
            userEmail = user.email;
            userRole = userData?['role'];
            userName = userData?['name'] ?? user.email?.split('@').first;
            profileImageUrl = userData?['profileImage'];
          }

          // معالجة بيانات التواصل (تكون النتيجة الثانية إذا وجد مستخدم، أو الأولى إذا لم يوجد)
          final contactDoc = (user != null ? results[1] : results[0]) as DocumentSnapshot;
          if (contactDoc.exists) {
            clinicContact = contactDoc.data() as Map<String, dynamic>?;
          }
          _isLoading = false; 
        });
      }
    } catch (e) {
      debugPrint("Error initializing settings: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showShippingPriceDialog(bool isAr, bool isDark) {
    final shippingController = TextEditingController(text: clinicContact?['defaultShippingPrice']?.toString() ?? '0');
    Color gold = const Color(0xFFC5A059);
    Color primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          isAr ? 'تعديل سعر الشحن' : 'Edit Shipping Price', 
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)
        ),
        content: _buildContactField(shippingController, isAr ? 'سعر الشحن ' : 'Shipping Price', Icons.local_shipping, isDark, gold, primaryColor, Colors.orange, keyboardType: TextInputType.number),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('config').doc('contact_info').update({
                'defaultShippingPrice': int.tryParse(shippingController.text) ?? 0,
              });
              _initializeData();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? gold : primaryColor,
              foregroundColor: isDark ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: Text(isAr ? 'حفظ' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchClinicContact() async {
    final doc = await FirebaseFirestore.instance.collection('config').doc('contact_info').get();
    if (doc.exists && mounted) {
      setState(() => clinicContact = doc.data());
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          userData = doc.data();
          userEmail = user.email;
          userRole = userData?['role'];
          userName = userData?['name'] ?? user.email?.split('@').first;
          profileImageUrl = userData?['profileImage'];
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      
      if (image != null) {
        setState(() => isUploading = true);
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        
        // رفع الصورة على Cloudinary
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(image.path, 
            resourceType: CloudinaryResourceType.Image,
            folder: 'profile_pictures'
          ),
        );

        final url = response.secureUrl;

        // تحديث الرابط في فيربيز
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profileImage': url,
        });

        if (mounted) {
          _fetchUserData();
          setState(() {
            isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة الشخصية')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الرفع: $e')));
      }
    }
  }

  Future<void> _launchSocial(String platform, String? value) async {
    if (value == null || value.isEmpty) return;
    
    Uri url;
    if (platform == 'whatsapp') {
      String phone = value;
      // إذا كان الرقم يبدأ بـ 0 وليس به رمز دولة، نضيف رمز مصر تلقائياً (+2)
      if (phone.startsWith('0')) {
        phone = '+2$phone';
      } else if (!phone.startsWith('+')) {
        phone = '+2$phone';
      }
      url = Uri.parse('https://wa.me/${phone.replaceAll(' ', '')}');
    } else if (platform == 'telegram') {
      url = Uri.parse(value.startsWith('http') ? value : 'https://t.me/$value');
    } else if (platform == 'facebook') {
      url = Uri.parse(value.startsWith('http') ? value : 'https://facebook.com/$value');
    } else {
      url = Uri.parse(value);
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    Color primaryColor = Theme.of(context).colorScheme.primary;
    bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
    Color textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) return const PetLoading(); // عرض شكل التحميل أثناء جلب البيانات

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الإعدادات' : 'Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: [
          _buildProfileCard(isAr, primaryColor, isDark),
          const SizedBox(height: 30),

          if (userRole == 'owner') ...[
            _buildSectionHeader(isAr ? 'تواصل معنا' : 'Contact Us', textColor),
            _buildSettingsGroup([
              _settingsItem(isAr ? 'واتساب' : 'WhatsApp', null, Colors.green, () => _launchSocial('whatsapp', clinicContact?['whatsapp'] ?? '+201000527852'), isDark, isWhatsApp: true),
              _settingsItem(isAr ? 'فيسبوك' : 'Facebook', Icons.facebook, Colors.blueAccent, () => _launchSocial('facebook', clinicContact?['facebook'] ?? 'https://www.facebook.com/profile.php?id=61591325165355'), isDark, customIconColor: Colors.blueAccent),
            ], isDark),
            const SizedBox(height: 25),
          ],

          if (userRole == 'doctor') ...[
            _buildSectionHeader(isAr ? 'إدارة العيادة والمتجر' : 'Clinic & Shop Management', textColor),
            _buildSettingsGroup([
              _settingsItem(isAr ? 'تعديل معلومات التواصل' : 'Edit Contact Info', Icons.edit_note, primaryColor, () => _showEditContactDialog(isAr, isDark), isDark),
              _settingsItem(isAr ? 'سعر الشحن الموحد' : 'Global Shipping Price', Icons.local_shipping_outlined, primaryColor, () => _showShippingPriceDialog(isAr, isDark), isDark),
            ], isDark),
            const SizedBox(height: 25),
          ],

          _buildSectionHeader(isAr ? 'إعدادات التطبيق' : 'App Settings', textColor),
          _buildSettingsGroup([
            _settingsItem(isAr ? 'اللغة' : 'Language', Icons.language, primaryColor, () => _showLanguageDialog(isAr), isDark),
            _settingsItem(isAr ? 'المظهر (اللون)' : 'Appearance', Icons.palette_outlined, primaryColor, () => _showColorPicker(isAr), isDark),
          ], isDark),

          const SizedBox(height: 30),
          _buildSectionHeader(isAr ? 'الحساب' : 'Account', textColor),
          _buildSettingsGroup([
            ListTile(
              onTap: () => _showLogoutDialog(isAr),
              leading: Icon(Icons.logout, color: isDark ? const Color(0xFFFF7088) : const Color(0xFFFF4D6D)),
              title: Text(
                isAr ? 'تسجيل الخروج' : 'Logout',
                style: TextStyle(
                  color: isDark ? const Color(0xFFFF7088) : const Color(0xFFFF4D6D), 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ], isDark),
        ],
      ),
    );
  }

  void _showLogoutDialog(bool isAr) {
    bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
    Color textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          isAr ? 'تسجيل الخروج' : 'Logout',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAr ? 'هل أنت متأكد من رغبتك في تسجيل الخروج؟' : 'Are you sure you want to logout?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey))
          ),
          ElevatedButton(
            onPressed: () async { 
              Navigator.pop(context); 
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginView()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D6D), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isAr, Color color, bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (userData != null) {
            Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileEditView(userData: userData!))).then((updated) {
              if (updated == true) {
                _fetchUserData();
                if (widget.onProfileUpdated != null) widget.onProfileUpdated!(); // تحديث الشاشة الرئيسية فوراً
              }
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : Colors.transparent),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: color.withOpacity(0.1),
                        backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty) ? NetworkImage(profileImageUrl!) : null,
                        child: (profileImageUrl == null || profileImageUrl!.isEmpty) ? Icon(Icons.person, size: 40, color: color) : null,
                      ),
                      if (isUploading)
                        const Positioned.fill(child: CircularProgressIndicator()),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickProfileImage,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: color,
                            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName ?? '---', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            Text(userEmail ?? '---', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                userRole == 'doctor' ? (isAr ? 'طبيب' : 'Doctor') : (isAr ? 'صاحب أليف' : 'Owner'),
                                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                  Icon(Icons.edit_outlined, color: Colors.grey.shade400),
                ],
              ),
              if (userData != null && (userData?['facebook'] != null || userData?['instagram'] != null || userData?['telegram'] != null || userData?['whatsapp'] != null)) ...[
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (userData?['facebook'] != null && userData!['facebook'].toString().isNotEmpty)
                      _socialIcon(Icons.facebook, Colors.blue, () => _launchSocial('facebook', userData!['facebook'])),
                    if (userData?['instagram'] != null && userData!['instagram'].toString().isNotEmpty)
                      _socialIcon(null, Colors.purple, () => _launchSocial('instagram', userData!['instagram']), imagePath: 'assets/insta.png'),
                    if (userData?['telegram'] != null && userData!['telegram'].toString().isNotEmpty)
                      _socialIcon(Icons.telegram, Colors.lightBlue, () => _launchSocial('telegram', userData!['telegram'])),
                    if (userData?['whatsapp'] != null && userData!['whatsapp'].toString().isNotEmpty)
                      _socialIcon(null, Colors.green, () => _launchSocial('whatsapp', userData!['whatsapp']), isWhatsApp: true),
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialIcon(IconData? icon, Color color, VoidCallback onTap, {bool isWhatsApp = false, String? imagePath}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: IconButton(
        icon: isWhatsApp 
          ? SvgPicture.asset('assets/WhatsApp.svg', width: 28, height: 28)
          : (imagePath != null 
              ? Image.asset(imagePath, width: 28, height: 28)
              : Icon(icon, color: color, size: 28)),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, right: 8),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildSettingsGroup(List<Widget> items, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
      ),
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: Column(children: items),
      ),
    );
  }

  Widget _settingsItem(String title, IconData? icon, Color color, VoidCallback onTap, bool isDark, {bool isWhatsApp = false, Color? customIconColor}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
        child: isWhatsApp 
          ? SvgPicture.asset('assets/WhatsApp.svg', width: 22, height: 22)
          : Icon(icon, color: customIconColor ?? (isDark ? Colors.white70 : Colors.black87), size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
      trailing: Icon(
        Icons.arrow_forward_ios, 
        size: 14, 
        color: Colors.grey.shade400
      ),
    );
  }

  void _showEditContactDialog(bool isAr, bool isDark) {
    final waController = TextEditingController(text: clinicContact?['whatsapp'] ?? '+201000527852');
    final fbController = TextEditingController(text: clinicContact?['facebook'] ?? 'https://www.facebook.com/profile.php?id=61591325165355');
    Color gold = const Color(0xFFC5A059);
    Color primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          isAr ? 'تعديل معلومات التواصل' : 'Edit Contact Info', 
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContactField(waController, isAr ? 'رقم الواتساب' : 'WhatsApp Number', Icons.phone, isDark, gold, primaryColor, Colors.green),
              const SizedBox(height: 16),
              _buildContactField(fbController, isAr ? 'رابط الفيسبوك' : 'Facebook Link', Icons.facebook, isDark, gold, primaryColor, Colors.blueAccent),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('config').doc('contact_info').set({
                'whatsapp': waController.text.trim(),
                'facebook': fbController.text.trim(),
              });
              _fetchClinicContact();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? gold : primaryColor,
              foregroundColor: isDark ? Colors.black87 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: Text(isAr ? 'حفظ' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactField(TextEditingController controller, String label, IconData icon, bool isDark, Color gold, Color primary, Color iconColor, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: isDark ? gold : iconColor),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? gold : primary, width: 1.5)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent,
      ),
    );
  }

  void _showLanguageDialog(bool isAr) {
    bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color gold = const Color(0xFFC5A059);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAr ? 'اختر اللغة' : 'Select Language',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 30),
            _languageOption('العربية', 'ar', isAr, isDark, gold, textColor),
            const SizedBox(height: 12),
            _languageOption('English', 'en', !isAr, isDark, gold, textColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(String label, String code, bool isSelected, bool isDark, Color gold, Color textColor) {
    return InkWell(
      onTap: () {
        _updateLanguage(code);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? gold.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? gold : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.language, color: isSelected ? gold : Colors.grey, size: 22),
            const SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: gold, size: 22),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(bool isAr) {
    bool isDark = Theme.of(context).scaffoldBackgroundColor.value == const Color(0xFF2D2D2D).value;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color gold = const Color(0xFFC5A059);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAr ? 'مظهر التطبيق' : 'App Appearance', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)
            ),
            const SizedBox(height: 30),
            _themeOption(
              isAr ? 'الذهبي الملكي' : 'Royal Gold',
              const Color(0xFFFDF9F5),
              MyApp.of(context).themeColor == const Color(0xFFFDF9F5),
              isDark, gold, textColor
            ),
            const SizedBox(height: 12),
            _themeOption(
              isAr ? 'المظهر الليلي' : 'Night Mode',
              const Color(0xFF2D2D2D),
              MyApp.of(context).themeColor == const Color(0xFF2D2D2D),
              isDark, gold, textColor
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(String label, Color colorValue, bool isSelected, bool isDark, Color gold, Color textColor) {
    return InkWell(
      onTap: () {
        _updateThemeColor(colorValue);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? gold.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? gold : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: colorValue,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400, width: 1.5),
                boxShadow: [if (isSelected) BoxShadow(color: colorValue.withOpacity(0.3), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: gold, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _updateLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    if (mounted) {
      MyApp.of(context).setLocale(Locale(code));
      setState(() {}); 
    }
  }

  Future<void> _updateThemeColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
    if (mounted) {
      MyApp.of(context).setThemeColor(color);
      setState(() {});
    }
  }
}
