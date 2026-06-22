import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../theme/theme.dart';
import 'policy_webview_screen.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;
  final int pendingCount;
  final int followCount;
  final int completedCount;
  final VoidCallback onSettingsChanged;

  const ProfileTab({
    super.key,
    required this.onLogout,
    required this.pendingCount,
    required this.followCount,
    required this.completedCount,
    required this.onSettingsChanged,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    final token = AuthState().token;
    if (token == null || token.isEmpty) return;

    try {
      final updatedProfile = await _apiService.fetchProfile(token);
      await AuthState().saveLogin(token, updatedProfile);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to refresh profile: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppTheme.statusCompleted,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }


  void _showSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final initialUseCommon = prefs.getBool('use_common_details') ?? false;
    final initialCommonMsg = AuthState().userProfile?['user_default_message'] ?? prefs.getString('common_message') ?? '';
    final initialCommonImgPath = prefs.getString('common_image_path') ?? '';

    final messageController = TextEditingController(text: initialCommonMsg);
    String dialogImagePath = initialCommonImgPath;
    bool dialogUseCommon = initialUseCommon;
    bool dialogLoading = false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: const [
                  Icon(Icons.settings_suggest_rounded, color: Color(0xFF0D9488)),
                  SizedBox(width: 12),
                  Text(
                    'Common Settings',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enable Common Details',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Switch.adaptive(
                          value: dialogUseCommon,
                          activeColor: const Color(0xFF0D9488),
                          onChanged: dialogLoading ? null : (val) {
                            dialogState(() {
                              dialogUseCommon = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Common Message field
                    TextFormField(
                      controller: messageController,
                      maxLines: 4,
                      minLines: 2,
                      enabled: !dialogLoading,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Common Message',
                        hintText: 'Enter message to send with leads',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0D9488), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Common Image section
                    const Text(
                      'Common Image/File',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (dialogImagePath.isNotEmpty) ...[
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: dialogImagePath.toLowerCase().endsWith('.pdf')
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 40),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: Text(
                                              dialogImagePath.split('/').last,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Image.file(
                                      File(dialogImagePath),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                                      ),
                                    ),
                            ),
                          ),
                          if (!dialogLoading)
                            IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                              onPressed: () {
                                dialogState(() {
                                  dialogImagePath = '';
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    OutlinedButton.icon(
                      onPressed: dialogLoading ? null : () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          dialogState(() {
                            dialogImagePath = pickedFile.path;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      icon: const Icon(Icons.image_search_rounded),
                      label: Text(dialogImagePath.isNotEmpty ? 'Change Image' : 'Pick Common Image'),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: dialogLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: dialogLoading ? null : () async {
                          final messageText = messageController.text.trim();
                          dialogState(() {
                            dialogLoading = true;
                          });
                          
                          try {
                            final token = AuthState().token ?? '';
                            if (token.isNotEmpty) {
                              // Sync message to backend
                              await _apiService.updateDefaultMessage(
                                token: token,
                                message: messageText,
                              );
                              // Refresh profile to keep UI and AuthState completely in sync
                              final updatedProfile = await _apiService.fetchProfile(token);
                              await AuthState().saveLogin(token, updatedProfile);
                            }

                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('use_common_details', dialogUseCommon);
                            await prefs.setString('common_message', messageText);
                            await prefs.setString('common_image_path', dialogImagePath);
                            
                            widget.onSettingsChanged();
                            if (context.mounted) {
                              Navigator.pop(context);
                              _showSnackBar('Settings saved successfully.');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } finally {
                            dialogState(() {
                              dialogLoading = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: dialogLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 12),
              Text('Delete Account?', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'This action is permanent and cannot be undone. Are you sure you want to delete your profile and account details?',
            style: TextStyle(color: Color(0xFF475569), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                try {
                  final token = AuthState().token ?? '';
                  final success = await _apiService.deleteProfile(token);
                  
                  if (success) {
                    await AuthState().logout();
                    navigator.pushReplacementNamed('/login');
                    _showSnackBar('Account deleted successfully.');
                  }
                } catch (e) {
                  _showSnackBar(
                    'Failed to delete account: ${e.toString().replaceAll('Exception:', '').trim()}',
                    isError: true,
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final profile = AuthState().userProfile ?? {};
    final phoneNum = profile['mobile'] ?? '';
    final formKey = GlobalKey<FormState>();
    final mobileController = TextEditingController(text: phoneNum);
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool dialogLoading = false;
    bool obscureOld = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: const [
                  Icon(Icons.vpn_key_rounded, color: Color(0xFF6366F1)),
                  SizedBox(width: 12),
                  Text(
                    'Change Password',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: mobileController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Mobile Number',
                          hintText: 'Enter 10-digit number',
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF64748B)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter mobile number';
                          }
                          if (value.trim().length != 10) {
                            return 'Must be exactly 10 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Old Password',
                          hintText: 'Enter old password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF64748B),
                              size: 20,
                            ),
                            onPressed: () {
                              dialogState(() {
                                obscureOld = !obscureOld;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter old password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: 'Enter new password',
                          prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF64748B)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF64748B),
                              size: 20,
                            ),
                            onPressed: () {
                              dialogState(() {
                                obscureNew = !obscureNew;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter new password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: dialogLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: dialogLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                dialogState(() {
                                  dialogLoading = true;
                                });
                                try {
                                  final token = AuthState().token ?? '';
                                  await _apiService.changePassword(
                                    token: token,
                                    mobile: mobileController.text.trim(),
                                    oldPassword: oldPasswordController.text,
                                    newPassword: newPasswordController.text,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _showSnackBar('Password changed successfully');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                } finally {
                                  dialogState(() {
                                    dialogLoading = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: dialogLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthState().userProfile ?? {};
    final String phone = profile['mobile'] ?? 'Not Specified';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
       padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            


            // 2. Stats Dashboard Grid Title
            Row(
              children: const [
                Text(
                  'Overview Statistics',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats Cards Row
            Row(
              children: [
                _buildStatCard(
                  title: 'Pending',
                  count: widget.pendingCount,
                  color: const Color(0xFFD97706),
                  icon: Icons.pending_actions_rounded,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Follow Up',
                  count: widget.followCount,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.alarm_rounded,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  title: 'Completed',
                  count: widget.completedCount,
                  color: const Color(0xFF10B981),
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 3. Settings Items List
            Row(
              children: const [
                Text(
                  'Preferences & Security',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.phone_android_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Phone Number',
                    subtitle: phone,
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildSettingTile(
                    icon: Icons.vpn_key_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Change Password',
                    subtitle: 'Update account password',
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildSettingTile(
                    icon: Icons.settings_rounded,
                    iconColor: const Color(0xFF0D9488),
                    title: 'Settings',
                    subtitle: 'Manage common message & image',
                    onTap: _showSettingsDialog,
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildSettingTile(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Sign Out',
                    subtitle: 'Securely close session',
                    onTap: widget.onLogout,
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildSettingTile(
                    icon: Icons.delete_forever_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your profile',
                    onTap: _showDeleteConfirmation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }
}
