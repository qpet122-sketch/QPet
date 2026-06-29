import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vet/home/pet_loading.dart';
import 'package:vet/home/qr_scanner_view.dart';
import 'package:vet/home/add_animal_view.dart';
import 'package:vet/home/products_view.dart';
import 'package:vet/home/add_product_view.dart';
import 'package:vet/home/orders_list_view.dart';
import 'package:vet/home/admin_reports_view.dart';
import 'package:vet/home/settings_view.dart';
import 'package:vet/home/bulk_export_view.dart'; // إضافة الاستيراد
import 'package:vet/main.dart';
import 'add_admin_view.dart';
import 'edit_pet_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userRole = 'loading';
  String userName = '';
  int _selectedIndex = 0;
  int notificationCount = 0;
  int userCount = 0;
  int petCount = 0;
  List<Map<String, dynamic>> petsData = [];
  List<String> userPetIds = [];
  final GlobalKey _appQrKey = GlobalKey();
  final GlobalKey _petQrKey = GlobalKey();
  DateTime? _lastBackPressTime;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _userCountSubscription;
  StreamSubscription? _petCountSubscription;

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _userCountSubscription?.cancel();
    _petCountSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (mounted) {
          setState(() {
            userRole = data?['role'] ?? 'owner';
            userName = data?['name'] ?? user.email?.split('@').first ?? '';
            userPetIds = List<String>.from(data?['petIds'] ?? []);
          });
          
          if (userPetIds.isNotEmpty) {
            List<Map<String, dynamic>> fetchedPets = [];
            for (String pid in userPetIds) {
              final petDoc = await FirebaseFirestore.instance.collection('pets').doc(pid).get();
              if (petDoc.exists) {
                Map<String, dynamic> pData = petDoc.data()!;
                pData['id'] = pid; // حفظ المعرف للتمكن من المسح
                fetchedPets.add(pData);
              }
            }
            if (mounted) setState(() => petsData = fetchedPets);
          } else {
            if (mounted) setState(() => petsData = []);
          }
          
          _setupNotificationListener(user.uid, userRole);
          if (userRole == 'doctor') _fetchCounts();
        }
      } catch (e) {}
    }
  }

  void _fetchCounts() {
    _userCountSubscription?.cancel();
    _petCountSubscription?.cancel();

    _userCountSubscription = FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      if (mounted) setState(() => userCount = snapshot.docs.length);
    });

    _petCountSubscription = FirebaseFirestore.instance.collection('pets').snapshots().listen((snapshot) {
      if (mounted) setState(() => petCount = snapshot.docs.length);
    });
  }

  void _setupNotificationListener(String userId, String role) {
    _notificationSubscription?.cancel();
    if (role == 'doctor') {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('orders').where('status', isEqualTo: 'pending').snapshots().listen((snapshot) {
        if (mounted && FirebaseAuth.instance.currentUser != null) {
          setState(() => notificationCount = snapshot.docs.length);
        }
      });
    } else {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('orders').where('userId', isEqualTo: userId).where('seenByOwner', isEqualTo: false).snapshots().listen((snapshot) {
        if (mounted && FirebaseAuth.instance.currentUser != null) {
          setState(() => notificationCount = snapshot.docs.length);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryGreen = const Color(0xFF004040);
    Color gold = const Color(0xFFC5A059);

    if (userRole == 'loading') {
      return const
    Scaffold(body: Center(child: PetLoading()));
    }

    Widget body;
    if (_selectedIndex == 2) {
      body = SettingsView(onProfileUpdated: _fetchInitialData); // تمرير دالة التحديث
    } else if (_selectedIndex == 1) {
      body = userRole == 'doctor' ? const AdminReportsView() : _buildPetTab(isAr, primaryGreen, isDark, gold);
    } else {
      body = _buildHomeTab(isAr, primaryGreen, gold, isDark);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'اضغط مرة أخرى للخروج' : 'Press back again to exit')));
        } else { exit(0); }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // هذا السطر يحل مشكلة الـ Pixel Overflow عند فتح الكيبورد
        body: Stack(
          children: [
            Positioned.fill(child: body),
            _buildCustomBottomNav(primaryGreen, gold, isAr),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(bool isAr, Color green, Color gold, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleButton(Icons.notifications_none, green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListView()))),
              Image.asset('assets/final_logo-Photoroom.png', height: 40),
              _circleButton(Icons.share_outlined, Colors.grey, _showDownloadQr),
            ],
          ),
          const SizedBox(height: 30),
          Text(isAr ? 'مرحباً بك،' : 'Welcome,', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 16)),
          Text(userName, style: TextStyle(color: isDark ? Colors.white : green, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          
          _buildHeroCard(green, gold, isAr),
          
          const SizedBox(height: 30),
          _buildSectionHeader(isAr ? 'خدمات QPet 🐾' : 'QPet Services 🐾', gold),
          const SizedBox(height: 15),
          
          _buildMenuCard(isAr ? 'متجر المستلزمات' : 'Pet Shop', isAr ? 'تسوق أفضل المنتجات' : 'Shop premium products', Icons.storefront, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsView())), isDark, gold),
          const SizedBox(height: 15),
          _buildMenuCard(isAr ? 'طلباتي' : 'My Orders', isAr ? 'تابع حالة مشترياتك' : 'Track your orders', Icons.local_shipping_outlined, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListView())), isDark, gold, badge: notificationCount),
          
          if (userRole == 'doctor') ...[
            const SizedBox(height: 30),
            _buildSectionHeader(isAr ? 'لوحة الإدارة' : 'Admin Dashboard', gold),
            const SizedBox(height: 15),
            Row(children: [
              _buildStatBox(isAr ? 'المستخدمين' : 'Users', userCount, Icons.people_outline, Colors.blue, isDark),
              const SizedBox(width: 15),
              _buildStatBox(isAr ? 'الحيوانات' : 'Pets', petCount, Icons.pets_outlined, gold, isDark)
            ]),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                _buildGridCard(isAr ? 'إضافة أليف' : 'Add Pet', Icons.add_circle_outline, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAnimalView())), isDark),
                _buildGridCard(isAr ? 'تصدير الرموز' : 'Export Codes', Icons.file_download_outlined, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkExportView())), isDark),
                _buildGridCard(isAr ? 'إضافة منتج' : 'Add Product', Icons.add_shopping_cart_outlined, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductView())), isDark),
                _buildGridCard(isAr ? 'إضافة ادمن' : 'Add Admin', Icons.admin_panel_settings_outlined, gold, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAdminView())), isDark),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildHeroCard(Color green, Color gold, bool isAr) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerView())).then((_) => _fetchInitialData()),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(40),
          image: const DecorationImage(image: AssetImage('assets/scan_bg.jpg'), fit: BoxFit.cover, opacity: 0.4),
          border: Border.all(color: gold.withOpacity(0.5), width: 1.5),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isAr ? 'ماسح الـ QR' : 'QR Scanner', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(isAr ? 'افحص كود أليفك الآن' : 'Scan your pet code now', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 15),
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: gold.withOpacity(0.3), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.qr_code_scanner, color: gold, size: 24)),
                ],
              ),
            ),
            Positioned(
              bottom: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: gold, shape: BoxShape.circle, border: Border.all(color: green, width: 4)),
                child: const Icon(Icons.qr_code, color: Colors.black87, size: 30),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPetTab(bool isAr, Color color, bool isDark, Color gold) {
    if (petsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(isAr ? 'لم تقم بمسح رمز أليفك بعد' : 'No pet scanned yet', style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerView())).then((_) => _fetchInitialData()),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              child: Text(isAr ? 'افحص الرمز الآن' : 'Scan Now'),
            )
          ]
        )
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'QPet', 
              style: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 2, 
                color: Color(0xFF004040)
              )
            ),
          ),
          const SizedBox(height: 30),
          Text(isAr ? 'قائمة حيواناتي' : 'My Pets List', style: TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 15),
          ...petsData.map((pet) => _buildPetCard(pet, isAr, color, isDark, gold)).toList(),
          
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerView())).then((_) => _fetchInitialData()),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(isAr ? 'إضافة حيوان آخر' : 'Add another pet'),
                style: TextButton.styleFrom(foregroundColor: gold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(Map<String, dynamic> pet, bool isAr, Color color, bool isDark, Color gold) {
    String petId = pet['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: gold.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.pets, color: color),
        ),
        title: Text(pet['animalName'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : color)),
        subtitle: Text(
          '${pet['animalType'] ?? ''}${pet['animalBreed'] != null && pet['animalBreed'].toString().isNotEmpty ? ' - ${pet['animalBreed']}' : ''}', 
          style: TextStyle(color: gold, fontSize: 13)
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(Icons.qr_code_2, color: gold, size: 24), onPressed: () => _showPetQr(petId, pet, isAr, color)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24), onPressed: () => _confirmRemovePet(petId, pet['animalName'], isAr)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(children: [
              _petInfoRow(Icons.person_outline, isAr ? 'المالك:' : 'Owner:', pet['ownerName'], isDark),
              _petInfoRow(Icons.phone_outlined, isAr ? 'الهاتف:' : 'Phone:', pet['ownerPhone'], isDark),
              
              if (pet['weight'] != null || pet['age'] != null) ...[
                const Divider(height: 50),
                _buildSectionHeader(isAr ? 'السجل الطبي' : 'Medical Record', gold),
                const SizedBox(height: 20),
                _petInfoRow(Icons.monitor_weight_outlined, isAr ? 'الوزن:' : 'Weight:', '${pet['weight'] ?? '--'} kg', isDark),
                _petInfoRow(Icons.calendar_today_outlined, isAr ? 'العمر:' : 'Age:', pet['age'], isDark),
                _petInfoRow(Icons.content_cut_outlined, isAr ? 'التعقيم:' : 'Sterilization:', pet['sterilizationStatus'], isDark),
              ],
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPetView(petId: petId, initialData: pet))).then((v) { if(v==true) _fetchInitialData(); }),
                icon: const Icon(Icons.edit_document),
                label: Text(isAr ? 'تعديل البيانات' : 'Edit Details'),
                style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black87),
              )
            ]),
          ),
        ],
      ),
    );
  }

  void _confirmRemovePet(String petId, String name, bool isAr) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(isAr ? 'حذف من حسابي' : 'Remove from Account'),
        content: Text(isAr ? 'هل أنت متأكد من حذف "$name" من حسابك؟ لن يتم حذف البيانات الأصلية.' : 'Are you sure you want to remove "$name" from your account? Original data won\'t be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                'petIds': FieldValue.arrayRemove([petId])
              });
              if (mounted) {
                Navigator.pop(c);
                _fetchInitialData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(isAr ? 'حذف' : 'Remove'),
          ),
        ],
      ),
    );
  }

  Widget _petInfoRow(IconData icon, String label, String? value, bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10), 
    child: Row(children: [
      Icon(icon, size: 22, color: Colors.grey), 
      const SizedBox(width: 12), 
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)), 
      const Spacer(), 
      Text(value ?? '---', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87))
    ])
  );

  Widget _buildMenuCard(String title, String sub, IconData icon, Color iconColor, VoidCallback onTap, bool isDark, Color gold, {int badge = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isDark ? gold.withOpacity(0.3) : Colors.grey.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: iconColor)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12))
            ])),
            if (badge > 0) CircleAvatar(radius: 10, backgroundColor: const Color(0xFFFF4D6D), child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10))),
            Icon(Icons.arrow_forward_ios, size: 14, color: gold),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color gold) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [gold.withOpacity(0.5), Colors.transparent])))),
      ],
    );
  }

  Widget _circleButton(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: IconButton(icon: Icon(icon, color: color), onPressed: onTap),
    );
  }

  Widget _buildStatBox(String label, int count, IconData icon, Color color, bool isDark) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxWidth: 500), // حماية للشاشات العريضة
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white, 
        borderRadius: BorderRadius.circular(25), 
        border: Border.all(color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1))
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 10),
        Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))
      ]),
    ),
  );

  Widget _buildGridCard(String title, IconData icon, Color color, VoidCallback onTap, bool isDark) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 500), // حماية للشاشات العريضة
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white, 
        borderRadius: BorderRadius.circular(25), 
        border: Border.all(color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1))
      ),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 10),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87))
      ])),
    ),
  );

  Widget _buildCustomBottomNav(Color green, Color gold, bool isAr) {
    return Positioned(
      bottom: 25, left: 20, right: 20,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: gold.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_filled, isAr ? 'الرئيسية' : 'Home', 0, gold),
            _navCenterItem(green, gold),
            _navItem(Icons.settings, isAr ? 'الإعدادات' : 'Settings', 2, gold),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, Color gold) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? gold : Colors.white54, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? gold : Colors.white54, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _navCenterItem(Color green, Color gold) {
    bool isSelected = _selectedIndex == 1;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 1),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? gold : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : gold, width: 4),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? gold : green).withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(
          Icons.pets, 
          color: isSelected ? Colors.white : green, 
          size: 28
        ),
      ),
    );
  }

  void _showDownloadQr() {
    const downloadUrl = 'https://drive.google.com/file/d/1D1zcqoLgvFiJjJ54vQrYEKWtFQWFlGav/view?usp=sharing';
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), title: const Center(child: Text('QPet App')), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [RepaintBoundary(key: _appQrKey, child: Container(color: Colors.white, padding: const EdgeInsets.all(10), child: QrImageView(data: downloadUrl, size: 200, embeddedImage: const AssetImage('assets/final_logo-Photoroom.png'), embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)), eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.teal)))), const SizedBox(height: 20), ElevatedButton.icon(onPressed: _shareAppQr, icon: const Icon(Icons.share), label: const Text('مشاركة الرابط'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))]))));
  }

  Future<void> _shareAppQr() async {
    try {
      RenderRepaintBoundary boundary = _appQrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/app_qr.png').create();
      await imagePath.writeAsBytes(byteData!.buffer.asUint8List());
      await Share.shareXFiles([XFile(imagePath.path)], text: 'حمل تطبيق QPet من هنا');
    } catch (e) {}
  }

  void _showPetQr(String petId, Map<String, dynamic> pet, bool isAr, Color primaryColor) {
    final url = 'https://mohamedyasser37.github.io/qpet1/#/pet/$petId';
    final name = pet['animalName'] ?? '';
    final password = pet['editPassword'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Center(child: Text(isAr ? 'رمز الأليف الخاص بك' : 'Your Pet QR Code')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _petQrKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(Icons.pets, color: primaryColor, size: 30),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 200, 
                      height: 200, 
                      child: QrImageView(
                        data: url, 
                        version: QrVersions.auto, 
                        embeddedImage: const AssetImage('assets/final_logo-Photoroom.png'),
                        embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
                        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.circle, color: primaryColor)
                      )
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                  ],
                ),
              ),
            ),
            const Divider(),
            Text(isAr ? 'كلمة سر التعديل:' : 'Edit Password:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            SelectableText(password, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 2)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _sharePetQr(name, password),
            icon: Icon(Icons.share, color: primaryColor),
            label: Text(isAr ? 'مشاركة' : 'Share', style: TextStyle(color: primaryColor)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isAr ? 'إغلاق' : 'Close')),
        ],
      ),
    );
  }

  Future<void> _sharePetQr(String name, String password) async {
    try {
      RenderRepaintBoundary boundary = _petQrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/pet_qr.png').create();
      await imagePath.writeAsBytes(byteData!.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(imagePath.path)], 
        text: 'QPet - بيانات الأليف: $name\nكلمة سر التعديل: $password'
      );
    } catch (e) {}
  }
}
