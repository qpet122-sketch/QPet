import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vet/main.dart';

class EditPetView extends StatefulWidget {
  final String petId;
  final Map<String, dynamic> initialData;

  const EditPetView({super.key, required this.petId, required this.initialData});

  @override
  State<EditPetView> createState() => _EditPetViewState();
}

class _EditPetViewState extends State<EditPetView> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController _breedController; // كود جديد
  late TextEditingController _ownerNameController;
  late TextEditingController _ownerPhoneController;
  late TextEditingController _weightController;
  late TextEditingController _ageController;
  
  String? _gender;
  String? _sterilizationStatus;

  List<Map<String, dynamic>> _vaccinations = [];
  List<Map<String, dynamic>> _surgeries = [];
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _dewormingDoses = [];
  List<String> _allergies = [];
  List<String> _chronicDiseases = [];

  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameController = TextEditingController(text: d['animalName'] ?? '');
    _typeController = TextEditingController(text: d['animalType'] ?? '');
    _breedController = TextEditingController(text: d['animalBreed'] ?? ''); // كود جديد
    _ownerNameController = TextEditingController(text: d['ownerName'] ?? '');
    _ownerPhoneController = TextEditingController(text: d['ownerPhone'] ?? '');
    _weightController = TextEditingController(text: d['weight']?.toString() ?? '');
    _ageController = TextEditingController(text: d['age']?.toString() ?? '');
    
    String g = d['gender']?.toString().toLowerCase() ?? '';
    _gender = (g == 'female' || g == 'أنثى') ? 'female' : 'male';

    String s = d['sterilizationStatus']?.toString().toLowerCase() ?? '';
    _sterilizationStatus = (s == 'yes' || s == 'نعم') ? 'yes' : 'no';

    _vaccinations = List<Map<String, dynamic>>.from(d['vaccinations_list'] ?? []);
    _surgeries = List<Map<String, dynamic>>.from(d['surgeries_list'] ?? []);
    _medications = List<Map<String, dynamic>>.from(d['medications_list'] ?? []);
    _dewormingDoses = List<Map<String, dynamic>>.from(d['deworming_list'] ?? []);
    _allergies = List<String>.from(d['allergies_list'] ?? []);
    _chronicDiseases = List<String>.from(d['chronic_diseases_list'] ?? []);
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, bool isDark) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: isDark ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFC5A059),
              onPrimary: Colors.black87,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ) : Theme.of(context),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _updatePet(bool isAr) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isUpdating = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final role = userDoc.data()?['role'];

      Map<String, dynamic> updateData = {
        'animalName': _nameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'ownerPhone': _ownerPhoneController.text.trim(),
        'animalType': _typeController.text.trim(),
        'animalBreed': _breedController.text.trim(), // كود جديد
        'gender': _gender == 'female' ? (isAr ? 'أنثى' : 'Female') : (isAr ? 'ذكر' : 'Male'),
        'weight': _weightController.text,
        'age': _ageController.text,
        'sterilizationStatus': _sterilizationStatus == 'yes' ? (isAr ? 'نعم' : 'Yes') : (isAr ? 'لا' : 'No'),
        'vaccinations_list': _vaccinations,
        'surgeries_list': _surgeries,
        'medications_list': _medications,
        'deworming_list': _dewormingDoses,
        'allergies_list': _allergies,
        'chronic_diseases_list': _chronicDiseases,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (role == 'owner') {
        updateData['ownerUid'] = user.uid;
      }

      await FirebaseFirestore.instance.collection('pets').doc(widget.petId).update(updateData);

      // 3. تحديث بيانات المستخدم إذا كان هو صاحب الحيوان
      if (role == 'owner' || updateData['ownerUid'] != null) {
        final ownerUid = updateData['ownerUid'] ?? user.uid;
        await FirebaseFirestore.instance.collection('users').doc(ownerUid).update({
          'name': _ownerNameController.text.trim(),
          'phone': _ownerPhoneController.text.trim(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تم حفظ السجل بنجاح' : 'Record Saved Successfully')));
        Navigator.pop(context, true);
      }
    } catch (e) { 
      if (mounted) {
        setState(() => isUpdating = false); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _editVaccination(bool isAr, int? index, bool isDark, Color gold) {
    final type = TextEditingController(text: index != null ? _vaccinations[index]['type'] : '');
    final date = TextEditingController(text: index != null ? _vaccinations[index]['date'] : '');
    final next = TextEditingController(text: index != null ? _vaccinations[index]['next'] : '');
    
    _showAddDialog(index == null ? (isAr ? 'إضافة تطعيم' : 'Add Vaccination') : (isAr ? 'تعديل تطعيم' : 'Edit Vaccination'), [
      _buildDialogField(type, isAr ? 'النوع' : 'Type', isDark, gold),
      _buildDateField(date, isAr ? 'التاريخ' : 'Date', isDark, gold),
      _buildDateField(next, isAr ? 'التاريخ القادم' : 'Next Date', isDark, gold),
    ], () {
      setState(() {
        final data = {'type': type.text, 'date': date.text, 'next': next.text};
        if (index == null) { _vaccinations.add(data); } else { _vaccinations[index] = data; }
      });
    }, isDark);
  }

  void _editSurgery(bool isAr, int? index, bool isDark, Color gold) {
    final name = TextEditingController(text: index != null ? _surgeries[index]['name'] : '');
    final date = TextEditingController(text: index != null ? _surgeries[index]['date'] : '');
    
    _showAddDialog(index == null ? (isAr ? 'إضافة عملية' : 'Add Surgery') : (isAr ? 'تعديل عملية' : 'Edit Surgery'), [
      _buildDialogField(name, isAr ? 'اسم العملية' : 'Surgery Name', isDark, gold, maxLines: 2),
      _buildDateField(date, isAr ? 'التاريخ' : 'Date', isDark, gold),
    ], () {
      setState(() {
        final data = {'name': name.text, 'date': date.text};
        if (index == null) { _surgeries.add(data); } else { _surgeries[index] = data; }
      });
    }, isDark);
  }

  void _editMedication(bool isAr, int? index, bool isDark, Color gold) {
    final name = TextEditingController(text: index != null ? _medications[index]['name'] : '');
    final dur = TextEditingController(text: index != null ? _medications[index]['duration'] : '');
    
    _showAddDialog(index == null ? (isAr ? 'إضافة دواء' : 'Add Medication') : (isAr ? 'تعديل دواء' : 'Edit Medication'), [
      _buildDialogField(name, isAr ? 'اسم الدواء' : 'Drug Name', isDark, gold, maxLines: 2),
      _buildDialogField(dur, isAr ? 'المدة / الجرعة' : 'Duration / Dose', isDark, gold, maxLines: 2),
    ], () {
      setState(() {
        final data = {'name': name.text, 'duration': dur.text};
        if (index == null) { _medications.add(data); } else { _medications[index] = data; }
      });
    }, isDark);
  }

  void _editDeworming(bool isAr, int? index, bool isDark, Color gold) {
    final name = TextEditingController(text: index != null ? _dewormingDoses[index]['name'] : '');
    final date = TextEditingController(text: index != null ? _dewormingDoses[index]['date'] : '');
    
    _showAddDialog(index == null ? (isAr ? 'إضافة جرعة ديدان' : 'Add Deworming Dose') : (isAr ? 'تعديل جرعة ديدان' : 'Edit Deworming Dose'), [
      _buildDialogField(name, isAr ? 'اسم الجرعة' : 'Dose Name', isDark, gold),
      _buildDateField(date, isAr ? 'تاريخ آخر جرعة' : 'Last Dose Date', isDark, gold),
    ], () {
      setState(() {
        final data = {'name': name.text, 'date': date.text};
        if (index == null) { _dewormingDoses.add(data); } else { _dewormingDoses[index] = data; }
      });
    }, isDark);
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color gold = const Color(0xFFC5A059);
    Color textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Text(isAr ? 'تعديل بيانات الأليف' : 'Edit Pet Data', style: const TextStyle(color: Colors.white)), 
        backgroundColor: primaryColor, 
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePdf(isAr),
            tooltip: isAr ? 'طباعة PDF' : 'Print PDF',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(isAr ? 'البيانات الأساسية' : 'Basic Info', Icons.info_outline, isDark ? gold : primaryColor),
              _buildField(_nameController, isAr ? 'اسم الحيوان' : 'Pet Name', Icons.pets, isDark, primaryColor, gold),
              const SizedBox(height: 12),
              
              _buildField(_typeController, isAr ? 'فصيلة الحيوان (قط، كلب...)' : 'Animal Species', Icons.category, isDark, primaryColor, gold),
              const SizedBox(height: 12),

              _buildField(_breedController, isAr ? 'سلالة الحيوان (شيرازي، هاسكي...)' : 'Animal Breed', Icons.pets_outlined, isDark, primaryColor, gold),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: isAr ? 'الجنس' : 'Gender',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.transgender, color: isDark ? gold : primaryColor),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? gold : primaryColor)),
                    ),
                    items: [
                      DropdownMenuItem(value: 'male', child: Text(isAr ? 'ذكر' : 'Male', style: TextStyle(color: textColor))),
                      DropdownMenuItem(value: 'female', child: Text(isAr ? 'أنثى' : 'Female', style: TextStyle(color: textColor))),
                    ],
                    onChanged: (val) => setState(() => _gender = val),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sterilizationStatus,
                    dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: isAr ? 'معقم / مخصي' : 'Neutered/Spayed',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.content_cut, color: isDark ? gold : primaryColor),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? gold : primaryColor)),
                    ),
                    items: [
                      DropdownMenuItem(value: 'yes', child: Text(isAr ? 'نعم' : 'Yes', style: TextStyle(color: textColor))),
                      DropdownMenuItem(value: 'no', child: Text(isAr ? 'لا' : 'No', style: TextStyle(color: textColor))),
                    ],
                    onChanged: (val) => setState(() => _sterilizationStatus = val),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: _buildField(_weightController, isAr ? 'الوزن (كجم)' : 'Weight (kg)', Icons.monitor_weight_outlined, isDark, primaryColor, gold, keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _buildField(_ageController, isAr ? 'العمر' : 'Age', Icons.calendar_today, isDark, primaryColor, gold)),
              ]),
              
              const SizedBox(height: 12),
              _buildField(_ownerNameController, isAr ? 'اسم الصاحب' : 'Owner Name', Icons.person, isDark, primaryColor, gold),
              const SizedBox(height: 12),
              _buildField(_ownerPhoneController, isAr ? 'رقم الهاتف' : 'Phone Number', Icons.phone, isDark, primaryColor, gold, keyboardType: TextInputType.phone),

              const Divider(height: 40),
              _buildListSection(isAr ? 'التطعيمات' : 'Vaccinations', Icons.vaccines, isDark ? gold : primaryColor, _vaccinations, 
                (item) => '${item['type']} - ${item['date']}', (index) => _editVaccination(isAr, index, isDark, gold), isDark),

              const Divider(height: 40),
              _buildListSection(isAr ? 'العمليات الجراحية' : 'Surgical Procedures', Icons.healing, Colors.red, _surgeries, 
                (item) => '${item['name']} (${item['date']})', (index) => _editSurgery(isAr, index, isDark, gold), isDark),

              const Divider(height: 40),
              _buildListSection(isAr ? 'الأدوية الحالية' : 'Current Medications', Icons.medication, Colors.teal, _medications, 
                (item) => '${item['name']} - ${item['duration']}', (index) => _editMedication(isAr, index, isDark, gold), isDark),

              const Divider(height: 40),
              _buildListSection(isAr ? 'جرعات الديدان' : 'Deworming Doses', Icons.bug_report, Colors.brown, _dewormingDoses, 
                (item) => '${item['name']} (${item['date']})', (index) => _editDeworming(isAr, index, isDark, gold), isDark),

              const Divider(height: 40),
              _buildSimpleListSection(isAr ? 'سجل الحساسية' : 'Allergies', Icons.warning_amber, Colors.orange, _allergies, isAr, isDark),

              const Divider(height: 40),
              _buildSimpleListSection(isAr ? 'الأمراض المزمنة' : 'Chronic Diseases', Icons.biotech, Colors.purple, _chronicDiseases, isAr, isDark),

              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isUpdating ? null : () => _updatePet(isAr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? gold : primaryColor, 
                  foregroundColor: isDark ? Colors.black87 : Colors.white,
                  minimumSize: const Size(double.infinity, 55), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: isUpdating ? const CircularProgressIndicator(color: Colors.white) : Text(isAr ? 'حفظ التعديلات' : 'Save Changes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))]));

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool isDark, Color primary, Color gold, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller, 
      keyboardType: keyboardType, 
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: isDark ? gold : primary), 
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? gold : primary)),
      ),
      validator: (v) => v!.isEmpty ? (MyApp.of(context).locale.languageCode == 'ar' ? 'مطلوب' : 'Required') : null,
    );
  }

  Widget _buildDateField(TextEditingController controller, String label, bool isDark, Color gold) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        readOnly: true,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        onTap: () => _selectDate(context, controller, isDark),
        decoration: InputDecoration(
          labelText: label, 
          labelStyle: const TextStyle(color: Colors.grey),
          suffixIcon: const Icon(Icons.calendar_month),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? gold : Colors.teal)),
        ),
      ),
    );
  }

  Widget _buildListSection(String title, IconData icon, Color color, List items, String Function(dynamic) labelBuilder, Function(int?) onEdit, bool isDark) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _buildSectionTitle(title, icon, color),
        IconButton(onPressed: () => onEdit(null), icon: Icon(Icons.add_circle, color: color)),
      ]),
      ...List.generate(items.length, (index) {
        final item = items[index];
        return Card(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(labelBuilder(item), style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => onEdit(index)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() => items.removeAt(index))),
              ],
            ),
          ),
        );
      }),
    ]);
  }

  Widget _buildSimpleListSection(String title, IconData icon, Color color, List<String> items, bool isAr, bool isDark) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _buildSectionTitle(title, icon, color),
        IconButton(
          onPressed: () => _showSimpleEditDialog(isAr, title, null, (val) {
            setState(() => items.add(val));
          }, isDark), 
          icon: Icon(Icons.add_circle, color: color)
        ),
      ]),
      ...List.generate(items.length, (index) {
        return Card(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(items[index], style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  onPressed: () => _showSimpleEditDialog(isAr, title, index, (val) {
                    setState(() => items[index] = val);
                  }, isDark),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => setState(() => items.removeAt(index)),
                ),
              ],
            ),
          ),
        );
      }),
    ]);
  }

  void _showSimpleEditDialog(bool isAr, String title, int? index, Function(String) onConfirm, bool isDark) {
    String initialValue = index != null ? (title == (isAr ? 'سجل الحساسية' : 'Allergies') ? _allergies[index] : _chronicDiseases[index]) : '';
    final controller = TextEditingController(text: initialValue);
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: TextField(
        controller: controller,
        maxLines: null,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: isAr ? 'اكتب هنا...' : 'Write here...',
          hintStyle: const TextStyle(color: Colors.grey),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? const Color(0xFFC5A059) : Colors.teal)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              onConfirm(controller.text);
              Navigator.pop(c);
            }
          }, 
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black87),
          child: Text(isAr ? 'تأكيد' : 'Confirm')
        ),
      ],
    ));
  }

  void _showAddDialog(String title, List<Widget> fields, VoidCallback onConfirm, bool isDark) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: () { onConfirm(); Navigator.pop(c); }, 
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black87),
          child: Text(isAr ? 'تأكيد' : 'Confirm')
        ),
      ],
    ));
  }

  Widget _buildDialogField(TextEditingController controller, String label, bool isDark, Color gold, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller, 
      maxLines: maxLines,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? gold : Colors.teal)),
      ),
    ),
  );

  Future<void> _generatePdf(bool isAr) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.amiriRegular();
    final fontBold = await PdfGoogleFonts.amiriBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(isAr ? 'تقرير طبي QPet' : 'QPet Medical Report', 
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: fontBold)),
                pw.Text(DateTime.now().toString().split(' ').first, style: pw.TextStyle(font: font)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          _pdfRow(isAr ? 'اسم الأليف:' : 'Pet Name:', _nameController.text, isAr, font, fontBold),
          _pdfRow(isAr ? 'الفصيلة:' : 'Species:', _typeController.text, isAr, font, fontBold),
          _pdfRow(isAr ? 'السلالة:' : 'Breed:', _breedController.text, isAr, font, fontBold),
          _pdfRow(isAr ? 'الجنس:' : 'Gender:', _gender == 'female' ? (isAr ? 'أنثى' : 'Female') : (isAr ? 'ذكر' : 'Male'), isAr, font, fontBold),
          _pdfRow(isAr ? 'الوزن:' : 'Weight:', '${_weightController.text} kg', isAr, font, fontBold),
          _pdfRow(isAr ? 'العمر:' : 'Age:', _ageController.text, isAr, font, fontBold),
          _pdfRow(isAr ? 'معقم/مخصي:' : 'Neutered:', _sterilizationStatus == 'yes' ? (isAr ? 'نعم' : 'Yes') : (isAr ? 'لا' : 'No'), isAr, font, fontBold),
          _pdfRow(isAr ? 'اسم المالك:' : 'Owner:', _ownerNameController.text, isAr, font, fontBold),
          _pdfRow(isAr ? 'رقم الهاتف:' : 'Phone:', _ownerPhoneController.text, isAr, font, fontBold),
          
          if (_vaccinations.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text(isAr ? 'التطعيمات' : 'Vaccinations', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: fontBold))),
            ..._vaccinations.map((v) => pw.Text('- ${v['type']} (${v['date']}) ${v['next'] != '' ? ' | Next: ${v['next']}' : ''}', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: font))),
          ],
          
          if (_surgeries.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text(isAr ? 'العمليات الجراحية' : 'Surgeries', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: fontBold))),
            ..._surgeries.map((s) => pw.Text('- ${s['name']} (${s['date']})', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: font))),
          ],
          
          if (_medications.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text(isAr ? 'الأدوية' : 'Medications', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: fontBold))),
            ..._medications.map((m) => pw.Text('- ${m['name']} (${m['duration']})', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: font))),
          ],

          if (_dewormingDoses.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text(isAr ? 'جرعات الديدان' : 'Deworming Doses', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: fontBold))),
            ..._dewormingDoses.map((d) => pw.Text('- ${d['name']} (${d['date']})', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: font))),
          ],
          
          if (_allergies.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text(isAr ? 'الحساسية' : 'Allergies', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: fontBold))),
            ..._allergies.map((a) => pw.Bullet(text: a, style: pw.TextStyle(font: font))),
          ],
          
          if (_chronicDiseases.isNotEmpty) ...[
            pw.Header(level: 1, child: pw.Text(isAr ? 'الأمراض المزمنة' : 'Chronic Diseases', textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr, style: pw.TextStyle(font: fontBold))),
            ..._chronicDiseases.map((c) => pw.Bullet(text: c, style: pw.TextStyle(font: font))),
          ],
          
          pw.Spacer(),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text('QPet Team - Smart Pet ID Solution', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey, font: font)),
          )
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfRow(String label, String value, bool isAr, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, 
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold)),
          pw.Text(value, 
            textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(value) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            style: pw.TextStyle(font: font)),
        ],
      ),
    );
  }
}
