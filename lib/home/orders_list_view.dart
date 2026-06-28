import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vet/main.dart';

class OrdersListView extends StatefulWidget {
  const OrdersListView({super.key});

  @override
  State<OrdersListView> createState() => _OrdersListViewState();
}

class _OrdersListViewState extends State<OrdersListView> {
  String? userRole;
  final currentUser = FirebaseAuth.instance.currentUser;

  final Map<String, Map<String, dynamic>> orderStatuses = {
    'pending': {'ar': 'قيد الانتظار', 'en': 'Pending', 'color': Colors.orange, 'step': 0},
    'processing': {'ar': 'جاري التجهيز', 'en': 'Processing', 'color': Colors.blue, 'step': 1},
    'shipped': {'ar': 'تم الشحن', 'en': 'Shipped', 'color': Colors.purple, 'step': 2},
    'delivered': {'ar': 'تم التوصيل', 'en': 'Delivered', 'color': Colors.green, 'step': 3},
    'rejected': {'ar': 'مرفوض', 'en': 'Rejected', 'color': Colors.red, 'step': -1},
  };

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (mounted) setState(() => userRole = doc.data()?['role'] ?? 'owner');
    }
  }

  void _markAsSeen() async {
    if (userRole != 'owner' || currentUser == null) return;
    final snapshot = await FirebaseFirestore.instance.collection('orders').where('userId', isEqualTo: currentUser!.uid).where('seenByOwner', isEqualTo: false).get();
    if (snapshot.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) { batch.update(doc.reference, {'seenByOwner': true}); }
      batch.commit().catchError((e) => debugPrint('Error: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color textColor = isDark ? Colors.white : Colors.black87;

    if (userRole == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    Query query = FirebaseFirestore.instance.collection('orders');
    if (userRole == 'owner') query = query.where('userId', isEqualTo: currentUser!.uid);
    
    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Text(userRole == 'doctor' ? (isAr ? 'إدارة الطلبات' : 'Order Management') : (isAr ? 'طلباتي' : 'My Orders'), style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor, 
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(isAr ? 'خطأ في جلب البيانات' : 'Error fetching data', style: TextStyle(color: textColor)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text(isAr ? 'لا توجد طلبات' : 'No orders', style: TextStyle(color: textColor)));

          final sortedOrders = docs.toList()..sort((a, b) {
            final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
            return (bTime ?? Timestamp.now()).compareTo(aTime ?? Timestamp.now());
          });

          if (userRole == 'owner') _markAsSeen();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            itemCount: sortedOrders.length,
            itemBuilder: (context, index) {
              final order = sortedOrders[index].data() as Map<String, dynamic>;
              return _buildOrderCard(context, sortedOrders[index].id, order, isAr, primaryColor, isDark, textColor);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, String orderId, Map<String, dynamic> order, bool isAr, Color primaryColor, bool isDark, Color textColor) {
    String status = order['status'] ?? 'pending';
    var statusInfo = orderStatuses[status] ?? orderStatuses['pending']!;
    int currentStep = statusInfo['step'];

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark ? BorderSide(color: Colors.white.withOpacity(0.05)) : BorderSide.none,
      ),
      elevation: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(isAr ? 'طلب #${orderId.substring(0,5)}' : 'Order #${orderId.substring(0,5)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: statusInfo['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(isAr ? statusInfo['ar'] : statusInfo['en'], style: TextStyle(color: statusInfo['color'], fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ]),
                const Divider(height: 24),
                if (order['items'] != null) ...(order['items'] as List).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${item['quantity']}x ${item['name']}', style: TextStyle(fontSize: 14, color: textColor)),
                    Text('${item['price']} ج.م', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                )),
                const Divider(height: 24),
                _infoRow(Icons.person_outline, '${isAr ? 'العميل:' : 'Client:'} ${order['userName']}', textColor),
                _infoRow(Icons.phone_outlined, '${isAr ? 'الهاتف:' : 'Phone:'} ${order['userPhone']}', textColor),
                _infoRow(Icons.location_on_outlined, '${isAr ? 'العنوان:' : 'Address:'} ${order['address']}', textColor),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(isAr ? 'الإجمالي النهائي:' : 'Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  Text('${order['totalPrice']} ج.م', style: TextStyle(color: isDark ? const Color(0xFFC5A059) : primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
                
                if (currentStep >= 0) ...[
                  const SizedBox(height: 25),
                  _buildTrackingIndicator(currentStep, isAr, isDark ? const Color(0xFFC5A059) : primaryColor),
                ],
              ],
            ),
          ),
          if (userRole == 'doctor') _buildDoctorActions(orderId, status, isAr, isDark),
        ],
      ),
    );
  }

  Widget _buildTrackingIndicator(int currentStep, bool isAr, Color color) {
    List<String> stepsAr = ['انتظار', 'تجهيز', 'شحن', 'توصيل'];
    List<String> stepsEn = ['Pending', 'Processing', 'Shipped', 'Delivered'];
    List<String> labels = isAr ? stepsAr : stepsEn;

    return Row(
      children: List.generate(4, (index) {
        bool isDone = index <= currentStep;
        bool isLast = index == 3;
        return Expanded(
          child: Row(children: [
            Column(children: [
              CircleAvatar(radius: 12, backgroundColor: isDone ? color : Colors.grey.shade300, child: Icon(index < currentStep ? Icons.check : Icons.circle, size: 12, color: Colors.white)),
              const SizedBox(height: 4),
              Text(labels[index], style: TextStyle(fontSize: 9, color: isDone ? color : Colors.grey, fontWeight: isDone ? FontWeight.bold : FontWeight.normal)),
            ]),
            if (!isLast) Expanded(child: Container(height: 2, color: index < currentStep ? color : Colors.grey.shade300, margin: const EdgeInsets.only(bottom: 15))),
          ]),
        );
      }),
    );
  }

  Widget _buildDoctorActions(String orderId, String currentStatus, bool isAr, bool isDark) {
    List<String> statuses = ['pending', 'processing', 'shipped', 'delivered', 'rejected'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.black12 : Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isAr ? 'تحديث حالة الطلب:' : 'Update Order Status:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statuses.map((s) {
                bool isSelected = s == currentStatus;
                var info = orderStatuses[s]!;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(isAr ? info['ar'] : info['en'], style: TextStyle(color: isSelected ? Colors.white : info['color'], fontSize: 11)),
                    selected: isSelected,
                    selectedColor: info['color'],
                    backgroundColor: info['color'].withOpacity(0.1),
                    onSelected: (val) { if (val) _updateStatus(orderId, s); },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color textColor) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: textColor)))]));

  void _updateStatus(String id, String status) {
    FirebaseFirestore.instance.collection('orders').doc(id).update({'status': status, 'seenByOwner': false});
  }
}
