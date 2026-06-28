import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet/home/add_product_view.dart';
import 'package:vet/home/empty_state_widget.dart';
import 'package:vet/main.dart';

// إدارة السلة
class CartItem {
  final Product product;
  int quantity;
  String? selectedColor;
  CartItem({required this.product, this.quantity = 1, this.selectedColor});

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
    'selectedColor': selectedColor,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product: Product.fromMap(json['product']),
    quantity: json['quantity'],
    selectedColor: json['selectedColor'],
  );
}

List<CartItem> cartItems = [];

// وظائف حفظ واسترجاع السلة
Future<void> saveCart() async {
  final prefs = await SharedPreferences.getInstance();
  final String encodedData = jsonEncode(cartItems.map((item) => item.toJson()).toList());
  await prefs.setString('qpet_cart', encodedData);
}

Future<void> loadCart() async {
  final prefs = await SharedPreferences.getInstance();
  final String? encodedData = prefs.getString('qpet_cart');
  if (encodedData != null) {
    final List<dynamic> decodedData = jsonDecode(encodedData);
    cartItems = decodedData.map((item) => CartItem.fromJson(item)).toList();
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double shippingPrice;
  final String imageUrl;
  final String category;
  final List<String> colors;

  Product({
    required this.id, 
    required this.name, 
    required this.description, 
    required this.price, 
    required this.shippingPrice,
    required this.imageUrl, 
    required this.category,
    this.colors = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description, 'price': price,
    'shippingPrice': shippingPrice, 'imageUrl': imageUrl, 'category': category, 'colors': colors,
  };

  factory Product.fromMap(Map<String, dynamic> data) => Product(
    id: data['id'], name: data['name'], description: data['description'],
    price: data['price'].toDouble(), shippingPrice: data['shippingPrice'].toDouble(),
    imageUrl: data['imageUrl'], category: data['category'],
    colors: List<String>.from(data['colors'] ?? []),
  );

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      shippingPrice: (data['shippingPrice'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? 'عام',
      colors: data['colors'] != null ? List<String>.from(data['colors']) : [],
    );
  }
}

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  String? userRole;

  @override
  void initState() {
    super.initState();
    _checkRole();
    loadCart().then((_) => setState(() {}));
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) setState(() => userRole = doc.data()?['role']);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color goldColor = const Color(0xFFC5A059);
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Text(isAr ? 'متجر المستلزمات' : 'Pet Shop', style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          if (userRole != 'doctor')
            Stack(
              children: [
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CartView())).then((_) => setState(() {})),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  iconSize: 30,
                ),
                if (cartItems.isNotEmpty)
                  Positioned(
                    right: 5, top: 5,
                    child: CircleAvatar(
                      radius: 9, backgroundColor: Colors.red,
                      child: Text('${cartItems.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
              ],
            )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.storefront_outlined,
              title: isAr ? 'المتجر فارغ' : 'Store is Empty',
              subtitle: isAr ? 'لم يتم إضافة أي منتجات حتى الآن' : 'No products have been added yet.',
            );
          }

          final products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.58,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => _buildProductCard(context, products[index], isAr, primaryColor, isDark, goldColor, textColor),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, bool isAr, Color primaryColor, bool isDark, Color goldColor, Color textColor) {
    bool isInCart = cartItems.any((item) => item.product.id == product.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white, 
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
        border: Border.all(color: isDark ? goldColor.withOpacity(0.2) : primaryColor.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      product.imageUrl, 
                      fit: BoxFit.cover, 
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(child: CircularProgressIndicator(strokeWidth: 2, value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null, color: isDark ? goldColor.withOpacity(0.5) : primaryColor.withOpacity(0.5)));
                      },
                      errorBuilder: (c, e, s) => Center(child: Icon(Icons.broken_image, color: primaryColor))
                    )
                  ),
                  Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? goldColor : primaryColor, borderRadius: BorderRadius.circular(10)), child: Text(product.category, style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                  if (userRole == 'doctor')
                    Positioned(top: 5, right: 5, child: PopupMenuButton<String>(icon: CircleAvatar(backgroundColor: isDark ? Colors.black54 : Colors.white, radius: 15, child: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black, size: 18)), onSelected: (val) { if (val == 'edit') Navigator.push(context, MaterialPageRoute(builder: (c) => AddProductView(product: product))); else if (val == 'delete') _confirmDelete(product.id, isAr); }, itemBuilder: (c) => [PopupMenuItem(value: 'edit', child: Text(isAr ? 'تعديل' : 'Edit')), PopupMenuItem(value: 'delete', child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)))])),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                  const SizedBox(height: 5),
                  Text('${product.price} ${isAr ? 'ج.م' : 'EGP'}', style: TextStyle(color: isDark ? goldColor : primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  if (userRole == 'owner')
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (isInCart) {
                            cartItems.removeWhere((item) => item.product.id == product.id);
                          } else {
                            cartItems.add(CartItem(product: product));
                          }
                          saveCart();
                        });
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: isInCart ? Colors.grey : (isDark ? goldColor : primaryColor), foregroundColor: isDark ? Colors.black87 : Colors.white, minimumSize: const Size(double.infinity, 35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: Text(isInCart ? (isAr ? 'تمت الإضافة' : 'Added') : (isAr ? 'أضف للسلة' : 'Add to Cart'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailView(product: product))).then((_) => setState(() {})), style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 30), foregroundColor: isDark ? goldColor.withOpacity(0.8) : primaryColor), child: Text(isAr ? 'التفاصيل' : 'Details', style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, bool isAr) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(isAr ? 'حذف المنتج' : 'Delete Product'), content: Text(isAr ? 'هل أنت متأكد؟' : 'Are you sure?'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel')), TextButton(onPressed: () { FirebaseFirestore.instance.collection('products').doc(id).delete(); Navigator.pop(c); }, child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)))]));
  }
}

class ProductDetailView extends StatefulWidget {
  final Product product;
  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  String? _userRole;
  String? _selectedColor;

  final Map<String, Color> colorMap = {
    'أسود': Colors.black, 'Black': Colors.black, 'أبيض': Colors.white, 'White': Colors.white, 'أحمر': Colors.red, 'Red': Colors.red, 'أزرق': Colors.blue, 'Blue': Colors.blue, 'أخضر': Colors.green, 'Green': Colors.green, 'أصفر': Colors.yellow, 'Yellow': Colors.yellow, 'بني': Colors.brown, 'Brown': Colors.brown, 'رمادي': Colors.grey, 'Grey': Colors.grey, 'وردي': Colors.pink, 'Pink': Colors.pink, 'بنفسجي': Colors.purple, 'Purple': Colors.purple, 'برتقالي': Colors.orange, 'Orange': Colors.orange,
  };

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    if (widget.product.colors.isNotEmpty) _selectedColor = widget.product.colors.first;
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) setState(() => _userRole = doc.data()?['role']);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color goldColor = const Color(0xFFC5A059);
    Color textColor = isDark ? Colors.white : Colors.black87;
    
    bool isThisColorInCart = cartItems.any((item) => item.product.id == widget.product.id && item.selectedColor == _selectedColor);

    return Scaffold(
      backgroundColor: themeBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400, pinned: true, backgroundColor: primaryColor, iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(background: Hero(tag: widget.product.id, child: Image.network(widget.product.imageUrl, fit: BoxFit.cover, loadingBuilder: (context, child, loadingProgress) { if (loadingProgress == null) return child; return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null, color: Colors.white.withOpacity(0.5))); }))),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: (isDark ? goldColor : primaryColor).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(widget.product.category, style: TextStyle(color: isDark ? goldColor : primaryColor, fontWeight: FontWeight.bold))), Text('${widget.product.price} ${isAr ? 'ج.م' : 'EGP'}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? goldColor : primaryColor))]),
                  const SizedBox(height: 20),
                  Text(widget.product.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 15),
                  if (widget.product.colors.isNotEmpty) ...[
                    Text(isAr ? 'الألوان المتاحة' : 'Available Colors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    SizedBox(height: 55, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: widget.product.colors.length, itemBuilder: (context, index) { String colorName = widget.product.colors[index]; bool isSelected = _selectedColor == colorName; Color displayColor = colorMap[colorName] ?? Colors.transparent; return GestureDetector(onTap: () => setState(() => _selectedColor = colorName), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: isSelected ? (isDark ? goldColor.withOpacity(0.1) : primaryColor.withOpacity(0.1)) : (isDark ? Colors.white.withOpacity(0.05) : Colors.white), borderRadius: BorderRadius.circular(15), border: Border.all(color: isSelected ? (isDark ? goldColor : primaryColor) : (isDark ? Colors.white10 : Colors.grey.shade300), width: 2)), child: Row(children: [Container(width: 18, height: 18, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400, width: 0.5))), const SizedBox(width: 8), Text(colorName, style: TextStyle(color: isSelected ? (isDark ? goldColor : primaryColor) : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))]))); })),
                    const SizedBox(height: 25),
                  ],
                  Text(isAr ? 'وصف المنتج' : 'Product Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),
                  Text(widget.product.description, style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.grey.shade600, height: 1.6)),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _userRole == 'owner' 
        ? Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]),
            child: SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    if (isThisColorInCart) {
                      cartItems.removeWhere((item) => item.product.id == widget.product.id && item.selectedColor == _selectedColor);
                    } else {
                      cartItems.add(CartItem(product: widget.product, selectedColor: _selectedColor));
                    }
                    saveCart();
                  });
                },
                icon: Icon(isThisColorInCart ? Icons.remove_shopping_cart : Icons.add_shopping_cart),
                label: Text(isThisColorInCart ? (isAr ? 'حذف هذا اللون' : 'Remove Color') : (isAr ? 'أضف هذا اللون للسلة' : 'Add Color to Cart'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: isThisColorInCart ? Colors.grey : (isDark ? goldColor : primaryColor), foregroundColor: isDark ? Colors.black87 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
          )
        : null,
    );
  }
}

class CartView extends StatefulWidget {
  const CartView({super.key});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    double totalProducts = cartItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(title: Text(isAr ? 'سلة المشتريات' : 'My Cart', style: const TextStyle(color: Colors.white)), backgroundColor: Theme.of(context).primaryColor, iconTheme: const IconThemeData(color: Colors.white), centerTitle: true),
      body: cartItems.isEmpty 
          ? EmptyStateWidget(icon: Icons.shopping_basket_outlined, title: isAr ? 'سلتك فارغة' : 'Empty Cart', subtitle: isAr ? 'لم تقم بإضافة أي منتجات للسلة بعد' : 'Your cart is empty.')
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    itemBuilder: (c, i) => Card(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: isDark ? BorderSide(color: Colors.white.withOpacity(0.05)) : BorderSide.none),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(cartItems[i].product.imageUrl, width: 60, height: 60, fit: BoxFit.cover)),
                            const SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cartItems[i].product.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), if (cartItems[i].selectedColor != null) Text('${isAr ? 'اللون:' : 'Color:'} ${cartItems[i].selectedColor}', style: const TextStyle(fontSize: 12, color: Colors.grey)), Text('${cartItems[i].product.price} ج.م', style: TextStyle(color: isDark ? const Color(0xFFC5A059) : Theme.of(context).primaryColor))])),
                            Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.remove_circle_outline, color: isDark ? Colors.white38 : Colors.black54), onPressed: () => setState(() { if (cartItems[i].quantity > 1) cartItems[i].quantity--; else cartItems.removeAt(i); saveCart(); })), Text('${cartItems[i].quantity}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)), IconButton(icon: Icon(Icons.add_circle_outline, color: isDark ? Colors.white38 : Colors.black54), onPressed: () => setState(() { cartItems[i].quantity++; saveCart(); }))]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isAr ? 'المجموع:' : 'Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)), Text('$totalProducts ${isAr ? 'ج.م' : 'EGP'}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFC5A059) : Theme.of(context).primaryColor))]),
                      const SizedBox(height: 20),
                      SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CheckoutView())), style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFFC5A059) : Theme.of(context).primaryColor, foregroundColor: isDark ? Colors.black87 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text(isAr ? 'الذهاب للدفع' : 'Proceed to Checkout', style: const TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}

class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  late TextEditingController _shippingController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    double maxShipping = 0;
    for (var item in cartItems) { if (item.product.shippingPrice > maxShipping) maxShipping = item.product.shippingPrice; }
    _shippingController = TextEditingController(text: maxShipping.toStringAsFixed(0));
    _fetchUserPhone();
  }

  Future<void> _fetchUserPhone() async {
    final user = fb_auth.FirebaseAuth.instance.currentUser; // تم تعديل هذا السطر
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _nameController.text = doc.data()?['name'] ?? '';
          _phoneController.text = doc.data()?['phone'] ?? '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    double totalProducts = cartItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
    double shipping = double.tryParse(_shippingController.text) ?? 0;
    double finalTotal = totalProducts + shipping;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(title: Text(isAr ? 'إتمام الطلب' : 'Checkout', style: const TextStyle(color: Colors.white)), backgroundColor: Theme.of(context).primaryColor, iconTheme: const IconThemeData(color: Colors.white), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildField(_nameController, isAr ? 'الاسم بالكامل' : 'Full Name', Icons.person, isDark),
            const SizedBox(height: 15),
            _buildField(_phoneController, isAr ? 'رقم الهاتف' : 'Phone Number', Icons.phone, isDark, keyboardType: TextInputType.phone),
            const SizedBox(height: 15),
            _buildField(_addressController, isAr ? 'العنوان بالتفصيل' : 'Detailed Address', Icons.location_on, isDark, maxLines: 3),
            const SizedBox(height: 15),
            _buildField(_shippingController, isAr ? 'سعر الشحن' : 'Shipping Cost', Icons.local_shipping, isDark, readOnly: true),
            const SizedBox(height: 30),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(15)), child: Column(children: [_summaryRow(isAr ? 'إجمالي المنتجات:' : 'Products Total:', '$totalProducts ${isAr ? 'ج.م' : 'EGP'}', isDark, textColor), _summaryRow(isAr ? 'سعر الشحن:' : 'Shipping:', '$shipping ${isAr ? 'ج.m' : 'EGP'}', isDark, textColor), const Divider(height: 30), _summaryRow(isAr ? 'الإجمالي النهائي:' : 'Total Amount:', '$finalTotal ${isAr ? 'ج.م' : 'EGP'}', isDark, textColor, isBold: true)])),
            const SizedBox(height: 40),
            if (isSaving) const CircularProgressIndicator()
            else SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _submitOrder, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text(isAr ? 'تأكيد الطلب' : 'Confirm Order', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool isDark, {TextInputType? keyboardType, int maxLines = 1, Function(String)? onChanged, bool readOnly = false}) {
    return TextField(controller: controller, keyboardType: keyboardType, maxLines: maxLines, onChanged: onChanged, readOnly: readOnly, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey), prefixIcon: Icon(icon, color: isDark ? const Color(0xFFC5A059) : Theme.of(context).primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)), filled: true, fillColor: readOnly ? (isDark ? Colors.black26 : Colors.grey.shade100) : (isDark ? Colors.white.withOpacity(0.02) : Colors.white)));
  }

  Widget _summaryRow(String label, String value, bool isDark, Color textColor, {bool isBold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? textColor : Colors.grey)), Text(value, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? (isDark ? const Color(0xFFC5A059) : Theme.of(context).primaryColor) : textColor))]));
  }

  Future<void> _submitOrder() async {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _addressController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'يرجى ملء جميع البيانات' : 'Please fill in all fields'), backgroundColor: Colors.red)); return; }
    setState(() => isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    double totalProducts = cartItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
    double shipping = double.tryParse(_shippingController.text) ?? 0;
    try {
      await FirebaseFirestore.instance.collection('orders').add({'userId': user?.uid, 'userName': _nameController.text, 'userPhone': _phoneController.text, 'address': _addressController.text, 'shippingCost': shipping, 'totalPrice': totalProducts + shipping, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp(), 'items': cartItems.map((e) => {'id': e.product.id, 'name': e.product.name, 'price': e.product.price, 'quantity': e.quantity, 'color': e.selectedColor}).toList()});
      cartItems.clear();
      await saveCart();
      if (mounted) { Navigator.pop(context); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلبك بنجاح!'), backgroundColor: Colors.green)); }
    } catch (e) { setState(() => isSaving = false); }
  }
}
