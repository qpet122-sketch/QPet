import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vet/home/edit_pet_view.dart';
import 'package:vet/home/empty_state_widget.dart';
import 'package:vet/main.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _qrKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _petScrollController = ScrollController();
  final ScrollController _userScrollController = ScrollController();

  String _searchQuery = '';
  
  // متغيرات التحديد المتعدد
  bool _isSelectionMode = false;
  final Set<String> _selectedPetIds = {};

  // متغيرات الـ Pagination للحيوانات
  List<DocumentSnapshot> _pets = [];
  bool _isLoadingPets = false;
  bool _hasMorePets = true;
  DocumentSnapshot? _lastPetDoc;

  // متغيرات الـ Pagination للمستخدمين
  List<DocumentSnapshot> _users = [];
  bool _isLoadingUsers = false;
  bool _hasMoreUsers = true;
  DocumentSnapshot? _lastUserDoc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // جلب البيانات الأولية
    _fetchPets();
    _fetchUsers();

    // الاستماع لسكروول الحيوانات للتحميل التلقائي
    _petScrollController.addListener(() {
      if (_petScrollController.position.pixels >= _petScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingPets && _hasMorePets && _searchQuery.isEmpty) _fetchPets();
      }
    });

    // الاستماع لسكروول المستخدمين للتحميل التلقائي
    _userScrollController.addListener(() {
      if (_userScrollController.position.pixels >= _userScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingUsers && _hasMoreUsers && _searchQuery.isEmpty) _fetchUsers();
      }
    });
  }

  Future<void> _fetchPets({bool reset = false}) async {
    if (_isLoadingPets) return;
    setState(() => _isLoadingPets = true);

    if (reset) {
      _pets = [];
      _lastPetDoc = null;
      _hasMorePets = true;
    }

    Query query = FirebaseFirestore.instance.collection('pets')
        .orderBy('timestamp', descending: true)
        .limit(20);

    if (_lastPetDoc != null) query = query.startAfterDocument(_lastPetDoc!);

    try {
      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      if (snapshot.docs.length < 20) _hasMorePets = false;
      if (snapshot.docs.isNotEmpty) {
        _lastPetDoc = snapshot.docs.last;
        _pets.addAll(snapshot.docs);
      }
    } catch (e) {
      debugPrint("Error fetching pets: $e");
    }

    if (mounted) setState(() => _isLoadingPets = false);
  }

  Future<void> _fetchUsers({bool reset = false}) async {
    if (_isLoadingUsers) return;
    setState(() => _isLoadingUsers = true);

    if (reset) {
      _users = [];
      _lastUserDoc = null;
      _hasMoreUsers = true;
    }

    Query query = FirebaseFirestore.instance.collection('users')
        .orderBy('email')
        .limit(20);

    if (_lastUserDoc != null) query = query.startAfterDocument(_lastUserDoc!);

    try {
      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      if (snapshot.docs.length < 20) _hasMoreUsers = false;
      if (snapshot.docs.isNotEmpty) {
        _lastUserDoc = snapshot.docs.last;
        _users.addAll(snapshot.docs);
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }

    if (mounted) setState(() => _isLoadingUsers = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _petScrollController.dispose();
    _userScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ... (دوال _shareQrCode و _showPetQr كما هي بدون تغيير)

  Future<void> _shareQrCode(String name, String password) async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (kIsWeb) {
        // في الويب نقوم بالتحميل/المشاركة باستخدام البيانات مباشرة
        await Share.shareXFiles(
          [XFile.fromData(pngBytes, name: 'qr_code.png', mimeType: 'image/png')],
          text: 'QPet - بيانات الأليف: $name\nكلمة سر التعديل: $password',
        );
      } else {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/qr_code.png').create();
        await imagePath.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(imagePath.path)], text: 'QPet - بيانات الأليف: $name\nكلمة سر التعديل: $password');
      }
    } catch (e) {
      debugPrint("Error sharing QR code: $e");
    }
  }

  void _showPetQr(String petId, Map<String, dynamic> pet, bool isAr, Color primaryColor, bool isDark) {
    final url = 'https://mohamedyasser37.github.io/qpet1/#/pet/$petId';
    final name = pet['animalName'] ?? '';
    final password = pet['editPassword'] ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(child: Text(isAr ? 'رمز الأليف' : 'Pet QR Code', style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Icon(Icons.pets, color: primaryColor, size: 30),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 180, 
                        height: 180, 
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: url, 
                              version: QrVersions.auto, 
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                            ),
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.all(2),
                              child: Image.asset('assets/final_logo-Photoroom.png', fit: BoxFit.contain),
                            ),
                          ],
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
              Text(password, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 2)),
            ],
          ),
        ),
        actions: [
          TextButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => EditPetView(petId: petId, initialData: pet))).then((v) { if(v==true) _fetchPets(reset: true); }); }, icon: const Icon(Icons.edit, color: Colors.orange), label: Text(isAr ? 'تعديل' : 'Edit', style: const TextStyle(color: Colors.orange))),
          TextButton.icon(onPressed: () => _shareQrCode(name, password), icon: Icon(Icons.share, color: primaryColor), label: Text(isAr ? 'مشاركة' : 'Share', style: TextStyle(color: primaryColor))),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isAr ? 'إغلاق' : 'Close', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedPetIds.length} ${isAr ? 'محدد' : 'Selected'}')
            : Text(isAr ? 'السجلات والنظام' : 'System Records', style: const TextStyle(color: Colors.white)),
        backgroundColor: _isSelectionMode ? Colors.red.shade900 : primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _isSelectionMode 
            ? IconButton(
                icon: const Icon(Icons.close), 
                onPressed: () => setState(() { _isSelectionMode = false; _selectedPetIds.clear(); })
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_forever), 
              onPressed: () => _confirmBulkDeletePets(isAr, isDark, primaryColor)
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: isAr ? 'بحث بالاسم أو البريد...' : 'Search by name or email...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) 
                        : null,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: isDark ? BorderSide(color: Colors.white.withOpacity(0.1)) : BorderSide.none),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(icon: const Icon(Icons.people), text: isAr ? 'المستخدمين' : 'Users'),
                  Tab(icon: const Icon(Icons.pets), text: isAr ? 'الحيوانات' : 'Pets'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(isAr, primaryColor, isDark, textColor),
          _buildPetsList(isAr, primaryColor, isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildUsersList(bool isAr, Color primaryColor, bool isDark, Color textColor) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    
    // فلترة محلية للمحملين حالياً
    final displayUsers = _users.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final email = (data['email'] ?? '').toString().toLowerCase();
      final name = (data['name'] ?? '').toString().toLowerCase();
      return email.contains(_searchQuery) || name.contains(_searchQuery);
    }).toList();

    if (displayUsers.isEmpty && !_isLoadingUsers) {
      return EmptyStateWidget(icon: Icons.person_search_outlined, title: isAr ? 'لا توجد نتائج' : 'No results found', subtitle: isAr ? 'لم نجد أي مستخدم يطابق بحثك' : 'No user matching your search.');
    }

    return ListView.separated(
      controller: _userScrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: displayUsers.length + (_isLoadingUsers ? 1 : 0),
      separatorBuilder: (c, i) => Divider(color: isDark ? Colors.white10 : Colors.grey.shade300),
      itemBuilder: (context, index) {
        if (index == displayUsers.length) return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
        
        final userData = displayUsers[index].data() as Map<String, dynamic>;
        final roleText = userData['role'] == 'doctor' ? (isAr ? 'طبيب' : 'Doctor') : (isAr ? 'صاحب أليف' : 'Owner');
        
        return ListTile(
          leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Icon(userData['role'] == 'doctor' ? Icons.medical_services : Icons.person, color: primaryColor)),
          title: Text(userData['email'] ?? '---', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          subtitle: Text('${isAr ? 'الرتبة:' : 'Role:'} $roleText', style: const TextStyle(color: Colors.grey)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (displayUsers[index].id != currentUid)
                IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20), onPressed: () => _confirmDeleteUser(displayUsers[index].id, userData, isAr, isDark)),
              Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white30 : Colors.grey.shade400),
            ],
          ),
          onTap: () => _showUserInfo(userData['email'] ?? '', userData['role'], isAr, primaryColor, isDark),
        );
      },
    );
  }

  Widget _buildPetsList(bool isAr, Color primaryColor, bool isDark, Color textColor) {
    final displayPets = _pets.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final animalName = (data['animalName'] ?? '').toString().toLowerCase();
      final ownerName = (data['ownerName'] ?? '').toString().toLowerCase();
      final petId = doc.id.toLowerCase();
      return animalName.contains(_searchQuery) || ownerName.contains(_searchQuery) || petId.contains(_searchQuery);
    }).toList();

    if (displayPets.isEmpty && !_isLoadingPets) {
      return EmptyStateWidget(icon: Icons.pets_outlined, title: isAr ? 'لا توجد نتائج' : 'No results found', subtitle: isAr ? 'لم نجد أي أليف يطابق بحثك' : 'No pet matching your search.');
    }

    return ListView.builder(
      controller: _petScrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: displayPets.length + (_isLoadingPets ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayPets.length) return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
        
        final doc = displayPets[index];
        final pet = doc.data() as Map<String, dynamic>;
        final bool isSelected = _selectedPetIds.contains(doc.id);

        return Card(
          color: isSelected ? Colors.red.withOpacity(0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15), 
            side: isSelected 
                ? const BorderSide(color: Colors.red, width: 2) 
                : (isDark ? BorderSide(color: Colors.white.withOpacity(0.05)) : BorderSide.none)
          ),
          child: ListTile(
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(doc.id);
              } else {
                _showPetQr(doc.id, pet, isAr, primaryColor, isDark);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedPetIds.add(doc.id);
                });
              }
            },
            leading: Stack(
              children: [
                Icon(Icons.pets, color: primaryColor, size: 30),
                if (isSelected)
                  const Positioned(
                    bottom: 0, right: 0,
                    child: CircleAvatar(radius: 8, backgroundColor: Colors.red, child: Icon(Icons.check, size: 10, color: Colors.white)),
                  ),
              ],
            ),
            title: Text(pet['animalName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            subtitle: Text(
              '${isAr ? 'الفصيلة:' : 'Species:'} ${pet['animalType'] ?? ''}${pet['animalBreed'] != null && pet['animalBreed'].toString().isNotEmpty ? ' (${pet['animalBreed']})' : ''} | ${isAr ? 'المالك:' : 'Owner:'} ${pet['ownerName'] ?? ''}', 
              style: const TextStyle(color: Colors.grey, fontSize: 12)
            ),
            trailing: _isSelectionMode 
                ? Checkbox(
                    value: isSelected, 
                    onChanged: (_) => _toggleSelection(doc.id),
                    activeColor: Colors.red,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pet['ownerPhone'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _confirmDeletePet(doc.id, pet, isAr, primaryColor, isDark)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedPetIds.contains(id)) {
        _selectedPetIds.remove(id);
        if (_selectedPetIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedPetIds.add(id);
      }
    });
  }

  void _confirmBulkDeletePets(bool isAr, bool isDark, Color color) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(isAr ? 'حذف جماعي' : 'Bulk Delete', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        content: Text(
          isAr 
            ? 'هل أنت متأكد من حذف ${_selectedPetIds.length} سجلات نهائياً؟ لا يمكن التراجع عن هذا الفعل.' 
            : 'Are you sure you want to permanently delete ${_selectedPetIds.length} records? This action cannot be undone.',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إغلاق' : 'Close')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              setState(() => _isLoadingPets = true);
              
              final batch = FirebaseFirestore.instance.batch();
              for (String id in _selectedPetIds) {
                batch.delete(FirebaseFirestore.instance.collection('pets').doc(id));
              }
              
              await batch.commit();
              
              setState(() {
                _isSelectionMode = false;
                _selectedPetIds.clear();
              });
              
              _fetchPets(reset: true);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isAr ? 'تم الحذف بنجاح' : 'Deleted successfully'),
                    backgroundColor: Colors.red,
                  )
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(isAr ? 'حذف الكل' : 'Delete All'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePet(String petId, Map<String, dynamic> data, bool isAr, Color color, bool isDark) {
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 10), Text(isAr ? 'تأكيد الحذف' : 'Confirm Delete', style: TextStyle(color: isDark ? Colors.white : Colors.black87))]),
      content: Text(isAr ? 'هل أنت متأكد من حذف سجل الأليف "${data['animalName']}"؟' : 'Delete "${data['animalName']}"?', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إغلاق' : 'Close', style: const TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('pets').doc(petId).delete(); if (mounted) { Navigator.pop(c); _fetchPets(reset: true); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text(isAr ? 'حذف' : 'Delete')),
      ],
    ));
  }

  void _confirmDeleteUser(String userId, Map<String, dynamic> data, bool isAr, bool isDark) {
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: Row(children: [const Icon(Icons.person_remove, color: Colors.red), const SizedBox(width: 10), Text(isAr ? 'حذف حساب نهائياً' : 'Permanent Delete', style: TextStyle(color: isDark ? Colors.white : Colors.black87))]),
      content: Text(
        isAr 
          ? 'هل أنت متأكد من حذف حساب "${data['name'] ?? data['email']}"؟ سيتم مسح بياناته من النظام فوراً.' 
          : 'Are you sure you want to delete "${data['name'] ?? data['email']}"? Their data will be removed from the system.', 
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: () async {
            try {
              // 1. حذف وثيقة المستخدم من Firestore
              await FirebaseFirestore.instance.collection('users').doc(userId).delete();
              
              // 2. إذا كان لديك إعداد Cloud Functions، سيتم حذف الـ Auth تلقائياً 
              // بناءً على حذف الوثيقة (OnDelete Trigger)
              
              if (mounted) {
                Navigator.pop(c);
                _fetchUsers(reset: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isAr ? 'تم حذف الحساب بنجاح' : 'User deleted successfully'), backgroundColor: Colors.red)
                );
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }, 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
          child: Text(isAr ? 'تأكيد الحذف' : 'Confirm Delete')
        ),
      ],
    ));
  }

  void _showUserInfo(String email, String role, bool isAr, Color primaryColor, bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (context) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(email, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)), const SizedBox(height: 20), Text(role == 'doctor' ? (isAr ? 'صلاحيات كاملة' : 'Admin Access') : (isAr ? 'صلاحيات مستخدم' : 'User Access'), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)), const SizedBox(height: 30), ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), child: Text(isAr ? 'إغلاق' : 'Close'))])));
  }
}
