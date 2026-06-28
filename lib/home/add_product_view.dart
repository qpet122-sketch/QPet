import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:vet/main.dart';
import 'package:vet/home/products_view.dart';

class AddProductView extends StatefulWidget {
  final Product? product;
  const AddProductView({super.key, this.product});
  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _shippingPriceController;
  late TextEditingController _categoryController;
  
  List<String> selectedColors = [];
  File? _selectedImage;
  String? _existingImageUrl;
  bool isSaving = false;

  final Map<String, Color> colorMap = {
    'أسود': Colors.black, 'Black': Colors.black,
    'أبيض': Colors.white, 'White': Colors.white,
    'أحمر': Colors.red, 'Red': Colors.red,
    'أزرق': Colors.blue, 'Blue': Colors.blue,
    'أخضر': Colors.green, 'Green': Colors.green,
    'أصفر': Colors.yellow, 'Yellow': Colors.yellow,
    'بني': Colors.brown, 'Brown': Colors.brown,
    'رمادي': Colors.grey, 'Grey': Colors.grey,
    'وردي': Colors.pink, 'Pink': Colors.pink,
    'بنفسجي': Colors.purple, 'Purple': Colors.purple,
    'برتقالي': Colors.orange, 'Orange': Colors.orange,
  };

  final List<String> availableColorsAr = [
    'أسود', 'أبيض', 'أحمر', 'أزرق', 'أخضر', 'أصفر', 'بني', 'رمادي', 'وردي', 'بنفسجي', 'برتقالي'
  ];
  
  final List<String> availableColorsEn = [
    'Black', 'White', 'Red', 'Blue', 'Green', 'Yellow', 'Brown', 'Grey', 'Pink', 'Purple', 'Orange'
  ];

  final cloudinary = CloudinaryPublic('dpgb9n7y1', 'qpet-app', cache: false);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(text: widget.product?.description ?? '');
    _priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    _shippingPriceController = TextEditingController(text: widget.product?.shippingPrice.toString() ?? '0');
    _categoryController = TextEditingController(text: widget.product?.category ?? '');
    selectedColors = widget.product?.colors != null ? List<String>.from(widget.product!.colors) : [];
    _existingImageUrl = widget.product?.imageUrl;
  }

  Future<void> _pickImage(Color primaryColor, bool isDark, Color goldColor) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _existingImageUrl;
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_selectedImage!.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
      return null;
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
    List<String> colorOptions = isAr ? availableColorsAr : availableColorsEn;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Text(widget.product == null ? (isAr ? 'إضافة منتج' : 'Add Product') : (isAr ? 'تعديل المنتج' : 'Edit Product'), style: const TextStyle(color: Colors.white)), 
        backgroundColor: primaryColor, 
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _pickImage(primaryColor, isDark, goldColor),
                  child: Container(
                    height: 180, width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05), 
                      borderRadius: BorderRadius.circular(20), 
                      border: Border.all(color: isDark ? goldColor.withOpacity(0.3) : primaryColor.withOpacity(0.3))
                    ),
                    child: _selectedImage != null 
                        ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_selectedImage!, fit: BoxFit.cover)) 
                        : (_existingImageUrl != null 
                            ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(_existingImageUrl!, fit: BoxFit.cover)) 
                            : Icon(Icons.add_a_photo_outlined, size: 50, color: isDark ? goldColor : primaryColor)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildField(_nameController, isAr ? 'اسم المنتج' : 'Product Name', Icons.shopping_bag_outlined, isDark, primaryColor, goldColor, isAr),
              const SizedBox(height: 16),
              _buildField(_categoryController, isAr ? 'الفئة' : 'Category', Icons.category_outlined, isDark, primaryColor, goldColor, isAr),
              const SizedBox(height: 25),
              
              Text(isAr ? 'الألوان المتاحة:' : 'Available Colors:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colorOptions.map((color) {
                  final isSelected = selectedColors.contains(color);
                  final displayColor = colorMap[color] ?? Colors.transparent;
                  
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.5), width: 0.5)),
                        ),
                        const SizedBox(width: 6),
                        Text(color, style: TextStyle(color: isSelected ? Colors.white : textColor, fontSize: 12)),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          selectedColors.add(color);
                        } else {
                          selectedColors.remove(color);
                        }
                      });
                    },
                    selectedColor: isDark ? goldColor : primaryColor,
                    checkmarkColor: Colors.white,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 25),
              _buildField(_descController, isAr ? 'الوصف' : 'Description', Icons.description_outlined, isDark, primaryColor, goldColor, isAr, maxLines: 3),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField(_priceController, isAr ? 'السعر' : 'Price', Icons.attach_money_outlined, isDark, primaryColor, goldColor, isAr, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(_shippingPriceController, isAr ? 'سعر الشحن' : 'Shipping', Icons.local_shipping_outlined, isDark, primaryColor, goldColor, isAr, keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isSaving ? null : _save, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? goldColor : primaryColor, 
                  foregroundColor: isDark ? Colors.black87 : Colors.white,
                  minimumSize: const Size(double.infinity, 55), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ), 
                child: isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(isAr ? 'حفظ المنتج' : 'Save Product', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool isDark, Color primary, Color gold, bool isAr, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller, 
      maxLines: maxLines, 
      keyboardType: keyboardType, 
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: isDark ? gold : primary), 
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? gold : primary, width: 1.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent,
        filled: true,
      ), 
      validator: (val) => (val == null || val.isEmpty) ? (isAr ? 'مطلوب' : 'Required') : null
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || (_selectedImage == null && _existingImageUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء ملء كافة البيانات واختيار صورة')));
      return;
    }
    setState(() => isSaving = true);
    try {
      final url = await _uploadImage();
      if (url == null) throw 'Upload Error';
      
      final data = {
        'name': _nameController.text.trim(), 
        'description': _descController.text.trim(), 
        'price': double.parse(_priceController.text.trim()), 
        'shippingPrice': double.parse(_shippingPriceController.text.trim()),
        'imageUrl': url, 
        'category': _categoryController.text.trim(), 
        'colors': selectedColors,
        'updatedAt': FieldValue.serverTimestamp()
      };
      if (widget.product == null) { 
        data['createdAt'] = FieldValue.serverTimestamp(); 
        await FirebaseFirestore.instance.collection('products').add(data); 
      }
      else { 
        await FirebaseFirestore.instance.collection('products').doc(widget.product!.id).update(data); 
      }
      if (mounted) Navigator.pop(context);
    } catch (e) { 
      setState(() => isSaving = false); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
