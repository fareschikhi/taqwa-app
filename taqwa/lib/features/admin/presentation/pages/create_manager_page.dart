import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'package:taqwa/features/data/services/image_upload_service.dart';
// import '../../../../core/models/halaqa_model.dart';
import '../../../../features/data/repositories/manager_repository.dart';
// import '../../../../features/data/repositories/halaqa_repository.dart';
import '../../../../features/data/models/manager_model.dart';

class CreateManagerPage extends StatefulWidget {
  /// Pass [editManager] to pre-fill the form for editing an existing manager.
  const CreateManagerPage({super.key, this.editManager});
  final ManagerModel? editManager;

  @override
  State<CreateManagerPage> createState() => _CreateManagerPageState();
}

class _CreateManagerPageState extends State<CreateManagerPage> {
  final _repo = ManagerRepository();
  // final _halaqaRepo = HalaqaRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  // List<HalaqaModel> _allHalaqas = [];
  // final Set<int> _selectedHalaqaIds = {};
  bool _canManageAccounts = false;
  bool _canDeleteAccounts = false;
  bool get _isEditing => widget.editManager != null;

  @override
  void initState() {
    super.initState();
    // _loadHalaqas();
    if (_isEditing) {
      final m = widget.editManager!;
      _nameController.text = m.fullName;
      _phoneController.text = m.phone ?? '';
      _emailController.text = m.email ?? '';
      _canManageAccounts = m.canManageAccounts;
      _canDeleteAccounts = m.canDeleteAccounts;
      // if (m.halaqas != null) {
      //   for (final h in m.halaqas!) {
      //     final id = h['id'];
      //     if (id != null) _selectedHalaqaIds.add(id as int);
      //   }
      // }
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: Text('اختيار من المعرض', style: AppTextStyles.bodyMd),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (img != null && mounted) {
                  setState(() => _selectedImage = img);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text('التقاط صورة بالكاميرا', style: AppTextStyles.bodyMd),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (img != null && mounted) {
                  setState(() => _selectedImage = img);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _loadHalaqas() async {
  //   try {
  //     final list = await _halaqaRepo.getAllHalaqas();
  //     if (mounted) setState(() => _allHalaqas = list);
  //   } catch (_) {}
  // }

  Future<void> _submit({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await ImageUploadService.uploadImage(_selectedImage!);
      }

      final data = <String, dynamic>{
        'fullName': _nameController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty)
          'phone': _phoneController.text.trim(),
        if (_emailController.text.trim().isNotEmpty)
          'email': _emailController.text.trim(),
        if (_passwordController.text.isNotEmpty)
          'password': _passwordController.text,
        if (avatarUrl != null) 'avatar': avatarUrl,
        'canManageAccounts': _canManageAccounts,
        'canDeleteAccounts': _canDeleteAccounts,
        // if (_selectedHalaqaIds.isNotEmpty)
        //   'halaqaIds': _selectedHalaqaIds.toList(),
      };

      if (_isEditing) {
        await _repo.updateManager(widget.editManager!.id!, data);
      } else {
        await _repo.createManager(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'تم تحديث بيانات المدير' : 'تم إضافة المدير بنجاح',
          ),
        ),
      );

      if (addAnother && !_isEditing) {
        _formKey.currentState!.reset();
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _passwordController.clear();
        // setState(() => _selectedHalaqaIds.clear());
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ManagerRepository.errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(height: 24.h),
                      // Photo upload
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 100.w,
                                    height: 100.w,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh,
                                      shape: BoxShape.circle,
                                      image: _selectedImage != null
                                          ? DecorationImage(
                                              image: FileImage(
                                                File(_selectedImage!.path),
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _selectedImage == null
                                        ? Icon(
                                            Icons.add_a_photo_outlined,
                                            color: AppColors.onSurfaceVariant,
                                            size: 36.w,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: Container(
                                      width: 32.w,
                                      height: 32.w,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.brandGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _selectedImage == null
                                            ? Icons.edit
                                            : Icons.check,
                                        color: AppColors.onPrimary,
                                        size: 16.w,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'الصورة الشخصية',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              _selectedImage != null
                                  ? 'تم اختيار صورة'
                                  : 'انقر لاختيار صورة (Cloudinary)',
                              style: AppTextStyles.labelSm.copyWith(
                                color: _selectedImage != null
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      // Section: Personal Data
                      _SectionHeader(
                        icon: Icons.manage_accounts_outlined,
                        title: 'البيانات الشخصية',
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'الاسم و اللقب',
                        hint: 'أدخل الاسم كاملاً',
                        controller: _nameController,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'الاسم مطلوب'
                            : null,
                      ),
                      SizedBox(height: 24.h),
                      // Section: Contact
                      _SectionHeader(
                        icon: Icons.contact_phone_outlined,
                        title: 'معلومات الاتصال',
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'رقم الهاتف',
                        hint: '05X XXX XXXX',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'البريد الإلكتروني',
                        hint: 'example@domain.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: _isEditing
                            ? 'كلمة المرور الجديدة (اتركه فارغاً للإبقاء)'
                            : 'كلمة المرور المبدئية',
                        hint: '••••••••',
                        controller: _passwordController,
                        obscureText: true,
                        validator: _isEditing
                            ? null
                            : (v) => v == null || v.isEmpty
                                  ? 'كلمة المرور مطلوبة'
                                  : null,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      // SizedBox(height: 24.h),
                      // // Section: Halaqa assignment
                      // _SectionHeader(
                      //   icon: Icons.menu_book_outlined,
                      //   title: 'الحلقات المعينة',
                      // ),
                      // SizedBox(height: 12.h),
                      // if (_allHalaqas.isEmpty)
                      //   Padding(
                      //     padding: EdgeInsets.symmetric(vertical: 8.h),
                      //     child: Text(
                      //       'لا توجد حلقات متاحة',
                      //       style: AppTextStyles.bodyMd.copyWith(
                      //           color: AppColors.onSurfaceVariant),
                      //       textAlign: TextAlign.right,
                      //     ),
                      //   )
                      // else
                      //   ..._allHalaqas.map((h) {
                      //     final id = h.id;
                      //     final name = h.name;
                      //     final level = h.level ?? '';
                      //     final isSelected = _selectedHalaqaIds.contains(id);
                      //     return GestureDetector(
                      //       onTap: () => setState(() {
                      //         if (isSelected) {
                      //           _selectedHalaqaIds.remove(id);
                      //         } else {
                      //           _selectedHalaqaIds.add(id);
                      //         }
                      //       }),
                      //       child: Container(
                      //         margin: EdgeInsets.only(bottom: 8.h),
                      //         padding: EdgeInsets.all(12.w),
                      //         decoration: BoxDecoration(
                      //           color: isSelected
                      //               ? AppColors.primaryContainer
                      //                   .withValues(alpha: 0.3)
                      //               : AppColors.surfaceContainerLowest,
                      //           borderRadius: BorderRadius.circular(
                      //               AppConstants.radiusMd),
                      //           border: Border.all(
                      //             color: isSelected
                      //                 ? AppColors.primaryContainer
                      //                 : AppColors.outlineVariant,
                      //           ),
                      //         ),
                      //         child: Row(
                      //           mainAxisAlignment:
                      //               MainAxisAlignment.spaceBetween,
                      //           children: [
                      //             Icon(
                      //               isSelected
                      //                   ? Icons.check_circle
                      //                   : Icons.circle_outlined,
                      //               color: isSelected
                      //                   ? AppColors.primary
                      //                   : AppColors.outline,
                      //               size: 20.w,
                      //             ),
                      //             Column(
                      //               crossAxisAlignment:
                      //                   CrossAxisAlignment.end,
                      //               children: [
                      //                 Text(
                      //                   name,
                      //                   style: AppTextStyles.bodyMd.copyWith(
                      //                     color: AppColors.onSurface,
                      //                     fontWeight: isSelected
                      //                         ? FontWeight.w600
                      //                         : FontWeight.w400,
                      //                   ),
                      //                 ),
                      //                 if (level.isNotEmpty)
                      //                   Text(
                      //                     level,
                      //                     style: AppTextStyles.labelSm
                      //                         .copyWith(
                      //                             color: AppColors
                      //                                 .onSurfaceVariant),
                      //                   ),
                      //               ],
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //     );
                      //   }),
                      SizedBox(height: 24.h),
                      _SectionHeader(
                        icon: Icons.shield_outlined,
                        title: 'الصلاحيات',
                      ),
                      SizedBox(height: 12.h),
                      _PrivilegeSwitch(
                        title: 'إنشاء وتعديل الحسابات',
                        subtitle: 'إضافة أو تعديل طالب أو ولي أمر وربطهم',
                        value: _canManageAccounts,
                        onChanged: (v) =>
                            setState(() => _canManageAccounts = v),
                      ),
                      SizedBox(height: 8.h),
                      _PrivilegeSwitch(
                        title: 'حذف الحسابات',
                        subtitle: 'حذف حساب طالب أو ولي أمر',
                        value: _canDeleteAccounts,
                        onChanged: (v) =>
                            setState(() => _canDeleteAccounts = v),
                      ),
                      SizedBox(height: 32.h),
                      // Buttons
                      AppButton(
                        label: _isEditing ? 'حفظ التعديلات' : 'حفظ المدير',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.save_outlined,
                        isLoading: _isLoading,
                        onPressed: () => _submit(),
                      ),
                      SizedBox(height: 12.h),
                      if (!_isEditing)
                        AppButton(
                          label: 'حفظ وإضافة آخر',
                          variant: AppButtonVariant.secondary,
                          icon: Icons.person_add,
                          onPressed: () => _submit(addAnother: true),
                        ),
                      if (!_isEditing) SizedBox(height: 12.h),
                      AppButton(
                        label: 'إلغاء',
                        variant: AppButtonVariant.tertiary,
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_forward_ios),
                color: AppColors.onSurface,
              ),
              const Spacer(),
              Text(
                'تقوى',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _isEditing ? 'تعديل مدير' : 'إضافة مدير جديد',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Icon(
                Icons.chevron_left,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              Text(
                'إدارة المديرين',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            _isEditing ? 'تعديل بيانات المدير' : 'إضافة مدير جديد',
            style: AppTextStyles.headlineLgMobile.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          Text(
            _isEditing
                ? 'قم بتحديث بيانات المدير.'
                : 'قم بإدخال بيانات المدير الجديد لإضافته إلى النظام.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
        ),
        SizedBox(width: 8.w),
        Icon(icon, color: AppColors.primary, size: 22.w),
      ],
    );
  }
}

class _PrivilegeSwitch extends StatelessWidget {
  const _PrivilegeSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primaryContainer.withValues(alpha: 0.3)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: value ? AppColors.primaryContainer : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
