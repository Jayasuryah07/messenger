import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../models/crm_model.dart';
import '../theme/theme.dart';
import 'pending_tab.dart';
import 'follow_tab.dart';
import 'completed_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<Lead> _leads = [];
  List<CompanyStatus> _statuses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<int, DateTime> _statusChangeTimes = {};
  String _currentSort = 'latest_updated';
  String _activeCompletedSubStatus = 'all';
  String _activePendingSubStatus = 'all';
  String _activeFollowSubStatus = 'all';
  bool _useCommonDetails = false;
  String _commonMessage = '';
  String _commonImagePath = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild to update top title & counts on tab changes
      }
    });
    AuthState().addListener(_onAuthStateChanged);
    _loadCommonSettings();
    _loadData();
  }

  Future<void> _loadCommonSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final profileMessage = AuthState().userProfile?['user_default_message']?.toString();
    if (mounted) {
      setState(() {
        _useCommonDetails = prefs.getBool('use_common_details') ?? false;
        _commonMessage = profileMessage ?? prefs.getString('common_message') ?? '';
        _commonImagePath = prefs.getString('common_image_path') ?? '';
      });
    }
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AuthState().removeListener(_onAuthStateChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = AuthState().token ?? '';
      final homeData = await _apiService.fetchHome(token);
      final List<Lead> loadedLeads = homeData['leads'] ?? [];
      final List<CompanyStatus> loadedStatuses = await _apiService.fetchCompanyStatus(token);

      // Fetch latest profile to keep default message in sync
      try {
        final updatedProfile = await _apiService.fetchProfile(token);
        await AuthState().saveLogin(token, updatedProfile);
        await _loadCommonSettings();
      } catch (profileError) {
        debugPrint('Failed to refresh profile in loadData: $profileError');
      }

      // Load status change times from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final Map<int, DateTime> loadedTimes = {};
      for (var lead in loadedLeads) {
        final savedTimeStr = prefs.getString('status_change_time_${lead.id}');
        if (savedTimeStr != null && savedTimeStr.isNotEmpty) {
          try {
            final parsed = DateFormat('dd MMM yyyy, hh:mm a').parse(savedTimeStr);
            loadedTimes[lead.id] = parsed;
          } catch (_) {
            loadedTimes[lead.id] = DateTime.now();
          }
        } else {
          try {
            final parsedDate = DateTime.parse(lead.dataCreated.trim());
            final withOffset = parsedDate.add(Duration(
              hours: 9 + (lead.id % 6),
              minutes: 10 + (lead.id % 45),
            ));
            loadedTimes[lead.id] = withOffset;
          } catch (_) {
            loadedTimes[lead.id] = DateTime.now();
          }
        }
      }

      setState(() {
        _leads = loadedLeads;
        _statuses = loadedStatuses.isNotEmpty 
            ? loadedStatuses 
            : (homeData['statuses'] as List<CompanyStatus>? ?? []);
        _statusChangeTimes = loadedTimes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading data: ${e.toString().replaceAll('Exception:', '').trim()}', isError: true);
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+\b|\b\s+'), '').replaceAll('-', '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      await launchUrl(uri);
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (err) {
        _showSnackBar('Could not launch dialer for number: $cleanPhone', isError: true);
      }
    }
  }

  Future<void> _openWhatsApp(Lead lead) async {
    final prefs = await SharedPreferences.getInstance();
    final useCommon = prefs.getBool('use_common_details') ?? false;
    final profileMessage = AuthState().userProfile?['user_default_message']?.toString();
    final commonMsg = profileMessage ?? prefs.getString('common_message') ?? '';
    final commonImgPath = prefs.getString('common_image_path') ?? '';

    var cleanPhone = lead.mobileNo.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final messageText = useCommon ? commonMsg : lead.message.trim();
    final hasAttachment = useCommon
        ? commonImgPath.isNotEmpty
        : (lead.fileAttached.trim().toLowerCase() == 'yes' &&
            lead.dataImage != null &&
            lead.dataImage!.trim().isNotEmpty);

    if (hasAttachment) {
      setState(() {
        _isLoading = true;
      });
      try {
        String finalFilePath = '';
        if (useCommon) {
          finalFilePath = commonImgPath;
        } else {
          final response = await http.get(Uri.parse(lead.mediaUrl));
          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${lead.dataImage}');
            await tempFile.writeAsBytes(response.bodyBytes);
            finalFilePath = tempFile.path;
          } else {
            setState(() {
              _isLoading = false;
            });
            _showSnackBar('Failed to download attachment for sharing.', isError: true);
            return;
          }
        }
        
        setState(() {
          _isLoading = false;
        });
        
        if (Platform.isAndroid) {
          const platform = MethodChannel('com.example.messanger/whatsapp_share');
          try {
            final bool success = await platform.invokeMethod('shareFile', {
              'filePath': finalFilePath,
              'phone': cleanPhone,
              'text': messageText,
            });
            if (!success) {
              await Share.shareXFiles(
                [XFile(finalFilePath)],
                text: messageText,
              );
            }
          } catch (e) {
            await Share.shareXFiles(
              [XFile(finalFilePath)],
              text: messageText,
            );
          }
        } else {
          await Share.shareXFiles(
            [XFile(finalFilePath)],
            text: messageText,
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Error preparing attachment: ${e.toString()}', isError: true);
      }
      return;
    }

    // Default to plain text share if no attachment is present
    final urlText = Uri.encodeComponent(messageText);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$urlText');
    
    try {
      final success = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!success) {
        final whatsappSchema = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$urlText');
        await launchUrl(whatsappSchema, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      try {
        final whatsappSchema = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$urlText');
        await launchUrl(whatsappSchema, mode: LaunchMode.externalApplication);
      } catch (err) {
        _showSnackBar('Could not launch WhatsApp for number: $cleanPhone', isError: true);
      }
    }
  }

  void _promptEmailAndLaunch(Lead lead) async {
    final prefs = await SharedPreferences.getInstance();
    final useCommon = prefs.getBool('use_common_details') ?? false;
    final profileMessage = AuthState().userProfile?['user_default_message']?.toString();
    final commonMsg = profileMessage ?? prefs.getString('common_message') ?? '';
    final displayMessage = useCommon ? commonMsg : lead.message;

    final emailController = TextEditingController();
    if (!mounted) return;
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
              Icon(Icons.email_outlined, color: Color(0xFF6366F1)),
              SizedBox(width: 12),
              Text('Send Email', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter email address to contact this lead:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Color(0xFF0F172A)),
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Recipient Email',
                  hintText: 'name@company.com',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                  _showSnackBar('Please enter a valid email address.', isError: true);
                  return;
                }
                Navigator.of(context).pop();
                
                final subject = Uri.encodeComponent('CRM Lead Inquiry');
                final body = Uri.encodeComponent(
                  'Hello,\n\nWe are reaching out to you regarding your lead inquiry:\n"$displayMessage"\n\nContact Details:\nPhone: ${lead.mobileNo}\n\nBest regards,\n${AuthState().userProfile?['name'] ?? 'CRM Team'}'
                );
                final mailUri = Uri.parse('mailto:$email?subject=$subject&body=$body');
                
                try {
                  await launchUrl(mailUri);
                } catch (e) {
                  try {
                    await launchUrl(mailUri, mode: LaunchMode.externalApplication);
                  } catch (err) {
                    _showSnackBar('Could not launch email composer.', isError: true);
                  }
                }
              },
              child: const Text('Compose', style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateFollowupDateTime(Lead lead) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        final activeThemeColor = _tabController.index == 0
            ? const Color(0xFFD97706)
            : _tabController.index == 1
                ? const Color(0xFF3B82F6)
                : const Color(0xFF10B981);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: activeThemeColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        final activeThemeColor = _tabController.index == 0
            ? const Color(0xFFD97706)
            : _tabController.index == 1
                ? const Color(0xFF3B82F6)
                : const Color(0xFF10B981);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: activeThemeColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
    final String hour = pickedTime.hour.toString().padLeft(2, '0');
    final String minute = pickedTime.minute.toString().padLeft(2, '0');
    final String formattedTime = '$hour:$minute:00';

    if (!mounted) return;

    // Show Confirmation Dialog for Scheduling Follow Up
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: const [
            Icon(Icons.calendar_month_rounded, color: Color(0xFF3B82F6)),
            SizedBox(width: 12),
            Text(
              'Confirm Follow Up',
              style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to schedule a follow-up for this lead on $formattedDate at ${pickedTime.format(context)}?',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Schedule', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = AuthState().token ?? '';
      final success = await _apiService.updateFollowup(
        token: token,
        dataId: lead.id,
        followupDate: formattedDate,
        followupTime: formattedTime,
        dataStatus: 'Follow Up',
      );

      if (success) {
        await AuthState.saveStatusChangeTime(lead.id, 'Follow Up');
        await _loadData();
        _showSnackBar('Followup date scheduled successfully.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to update followup: ${e.toString().replaceAll('Exception:', '').trim()}', isError: true);
    }
  }

  void _openStatusSelector(Lead lead) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final activeThemeColor = _tabController.index == 0
            ? const Color(0xFFD97706)
            : _tabController.index == 1
                ? const Color(0xFF3B82F6)
                : const Color(0xFF10B981);

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Lead Status',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _statuses.length,
                    itemBuilder: (context, index) {
                      final status = _statuses[index];
                      final isSelected = lead.dataStatus.trim().toLowerCase() == status.companyStatus.trim().toLowerCase();
                      
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 8,
                          backgroundColor: AppTheme.getStatusColor(status.companyStatus),
                        ),
                        title: Text(
                          status.companyStatus,
                          style: TextStyle(
                            color: isSelected ? activeThemeColor : const Color(0xFF475569),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected 
                            ? Icon(Icons.check, color: activeThemeColor) 
                            : null,
                        onTap: () async {
                          Navigator.of(context).pop();
                          
                          if (status.companyStatus.toLowerCase().trim() == 'follow up') {
                            _updateFollowupDateTime(lead);
                          } else {
                            setState(() {
                              _isLoading = true;
                            });
                            try {
                              final token = AuthState().token ?? '';
                              final success = await _apiService.updateFollowup(
                                token: token,
                                dataId: lead.id,
                                followupDate: '',
                                followupTime: '',
                                dataStatus: status.companyStatus,
                              );
                              if (success) {
                                await AuthState.saveStatusChangeTime(lead.id, status.companyStatus);
                                await _loadData();
                                _showSnackBar('Status updated to: ${status.companyStatus}');
                              }
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });
                              _showSnackBar(
                                'Failed to update status: ${e.toString().replaceAll('Exception:', '').trim()}', 
                                isError: true
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewAttachment(Lead lead) async {
    final prefs = await SharedPreferences.getInstance();
    final useCommon = prefs.getBool('use_common_details') ?? false;
    final commonImgPath = prefs.getString('common_image_path') ?? '';
    
    if (useCommon) {
      if (commonImgPath.isEmpty) return;
      final file = File(commonImgPath);
      if (!await file.exists()) {
        _showSnackBar('Common attachment file does not exist.', isError: true);
        return;
      }
      
      final isPdf = commonImgPath.toLowerCase().endsWith('.pdf');
      if (isPdf) {
        final uri = Uri.file(commonImgPath);
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _showSnackBar('Cannot open local PDF directly.', isError: true);
          }
        } catch (_) {
          _showSnackBar('Error opening local PDF.', isError: true);
        }
        return;
      }
      
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: const Text('Attached Common Media', style: TextStyle(fontSize: 16, color: Color(0xFF0F172A))),
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
      return;
    }

    if (lead.dataImage == null || lead.dataImage!.isEmpty) return;
    
    if (lead.hasPdf) {
      final uri = Uri.parse(lead.mediaUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open the attachment.', isError: true);
      }
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text('Attached Media', style: TextStyle(fontSize: 16, color: Color(0xFF0F172A))),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_browser_rounded, color: Color(0xFF6366F1)),
                    onPressed: () async {
                      final uri = Uri.parse(lead.mediaUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  )
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: lead.hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          lead.mediaUrl,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              color: const Color(0xFFF1F5F9),
                              child: const Center(
                                child: Text('Failed to load image preview', style: TextStyle(color: Colors.redAccent)),
                              ),
                            );
                          },
                        ),
                      )
                    : Container(
                        height: 200,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            const Text('PDF Attachment', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(lead.dataImage!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(lead.mediaUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.launch, color: Color(0xFF6366F1)),
                              label: const Text('Open PDF Document', style: TextStyle(color: Color(0xFF6366F1))),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _handleLogout() async {
    await AuthState().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out?'),
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<Lead> _getFilteredLeads(String tab) {
    var list = _leads;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((lead) {
        return lead.message.toLowerCase().contains(query) ||
            lead.mobileNo.contains(query);
      }).toList();
    }

    final statusTab = tab.toLowerCase().trim();
    List<Lead> filtered;
    if (statusTab == 'pending') {
      filtered = list.where((lead) => lead.dataStatus.trim().toLowerCase() == 'pending').toList();
    } else if (statusTab == 'follow') {
      filtered = list.where((lead) => 
        lead.dataStatus.trim().toLowerCase() == 'follow up' ||
        lead.dataStatus.trim().toLowerCase() == 'follow'
      ).toList();
    } else {
      filtered = list.where((lead) {
        final s = lead.dataStatus.trim().toLowerCase();
        return s != 'pending' && s != 'follow up' && s != 'follow';
      }).toList();
    }

    // Apply sorting
    if (_currentSort == 'latest_updated') {
      filtered.sort((a, b) {
        final timeA = _statusChangeTimes[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = _statusChangeTimes[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA); // descending (latest first)
      });
    } else if (_currentSort == 'created_newest') {
      filtered.sort((a, b) {
        DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
        try { dateA = DateTime.parse(a.dataCreated.trim()); } catch(_) {}
        try { dateB = DateTime.parse(b.dataCreated.trim()); } catch(_) {}
        return dateB.compareTo(dateA); // descending (newest first)
      });
    } else if (_currentSort == 'created_oldest') {
      filtered.sort((a, b) {
        DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
        try { dateA = DateTime.parse(a.dataCreated.trim()); } catch(_) {}
        try { dateB = DateTime.parse(b.dataCreated.trim()); } catch(_) {}
        return dateA.compareTo(dateB); // ascending (oldest first)
      });
    } else if (_currentSort == 'followup_soonest' && statusTab == 'follow') {
      filtered.sort((a, b) {
        DateTime dateA = DateTime.now().add(const Duration(days: 365 * 10)); // far future fallback
        DateTime dateB = DateTime.now().add(const Duration(days: 365 * 10));
        try {
          if (a.followupDate != null) {
            final datePart = a.followupDate!.trim();
            final timePart = a.followupTime?.trim() ?? '00:00:00';
            dateA = DateTime.parse('$datePart $timePart');
          }
        } catch(_) {}
        try {
          if (b.followupDate != null) {
            final datePart = b.followupDate!.trim();
            final timePart = b.followupTime?.trim() ?? '00:00:00';
            dateB = DateTime.parse('$datePart $timePart');
          }
        } catch(_) {}
        return dateA.compareTo(dateB); // ascending (soonest first)
      });
    }

    return filtered;
  }

  List<Lead> _applyPendingDateFilter(List<Lead> list) {
    if (_activePendingSubStatus == 'all') return list;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return list.where((lead) {
      try {
        final d = DateTime.parse(lead.dataCreated.trim());
        final dayOfD = DateTime(d.year, d.month, d.day);
        if (_activePendingSubStatus == 'today') {
          return dayOfD.year == today.year && dayOfD.month == today.month && dayOfD.day == today.day;
        } else if (_activePendingSubStatus == 'yesterday') {
          return dayOfD.year == yesterday.year && dayOfD.month == yesterday.month && dayOfD.day == yesterday.day;
        } else if (_activePendingSubStatus == 'older') {
          return dayOfD.isBefore(yesterday);
        }
      } catch (_) {}
      return false;
    }).toList();
  }

  List<Lead> _applyFollowDateFilter(List<Lead> list) {
    if (_activeFollowSubStatus == 'all') return list;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return list.where((lead) {
      try {
        if (lead.followupDate == null) return false;
        final d = DateTime.parse(lead.followupDate!.trim());
        final dayOfD = DateTime(d.year, d.month, d.day);
        if (_activeFollowSubStatus == 'today') {
          return dayOfD.year == today.year && dayOfD.month == today.month && dayOfD.day == today.day;
        } else if (_activeFollowSubStatus == 'tomorrow') {
          return dayOfD.year == tomorrow.year && dayOfD.month == tomorrow.month && dayOfD.day == tomorrow.day;
        } else if (_activeFollowSubStatus == 'expired') {
          return dayOfD.isBefore(today);
        }
      } catch (_) {}
      return false;
    }).toList();
  }



  void _showSortOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final currentTab = _tabController.index;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sort Leads By',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                _buildSortOptionItem(
                  title: 'Latest Updated First',
                  value: 'latest_updated',
                  icon: Icons.history_rounded,
                ),
                _buildSortOptionItem(
                  title: 'Created Date (Newest First)',
                  value: 'created_newest',
                  icon: Icons.calendar_today_rounded,
                ),
                _buildSortOptionItem(
                  title: 'Created Date (Oldest First)',
                  value: 'created_oldest',
                  icon: Icons.calendar_today_outlined,
                ),
                if (currentTab == 1) // Follow Up tab
                  _buildSortOptionItem(
                    title: 'Follow Up Date (Soonest First)',
                    value: 'followup_soonest',
                    icon: Icons.alarm_rounded,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOptionItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _currentSort == value;
    final activeThemeColor = _tabController.index == 0
        ? const Color(0xFFD97706)
        : _tabController.index == 1
            ? const Color(0xFF3B82F6)
            : const Color(0xFF10B981);

    return ListTile(
      leading: Icon(icon, color: isSelected ? activeThemeColor : const Color(0xFF64748B)),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? activeThemeColor : const Color(0xFF0F172A),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: activeThemeColor) : null,
      onTap: () {
        setState(() {
          _currentSort = value;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildTabAllCard({
    required String title,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE2E8F0),
            width: isActive ? 2.0 : 1.0,
          ),
          boxShadow: [
            isActive
                ? BoxShadow(
                    color: activeColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                : const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? activeColor : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF475569),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedItem({
    required String title,
    required int count,
    required bool isActive,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon, 
                    size: 13, 
                    color: isActive ? iconColor : const Color(0xFF94A3B8)
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isActive ? iconColor : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF475569),
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1.0,
      height: 20.0,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildBottomBarIcon(IconData icon, bool isActive, Color activeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: isActive ? 24 : 0,
          height: 3.5,
          decoration: BoxDecoration(
            color: activeColor,
            borderRadius: BorderRadius.circular(2),
            boxShadow: isActive ? [
              BoxShadow(
                color: activeColor.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              )
            ] : [],
          ),
        ),
        const SizedBox(height: 6),
        AnimatedScale(
          scale: isActive ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Icon(
            icon,
            size: 24,
            color: isActive ? activeColor : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  String _getInitials(String name) {
    if (name.isEmpty) return 'US';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _pickImage(StateSetter dialogState) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF6366F1)),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 40,
                      maxWidth: 1000,
                      maxHeight: 1000,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                      dialogState(() {});
                    }
                  } catch (e) {
                    debugPrint('Error picking image from gallery: $e');
                    _showSnackBar('Failed to open gallery: $e. Please rebuild the app.', isError: true);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6366F1)),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 40,
                      maxWidth: 1000,
                      maxHeight: 1000,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                      dialogState(() {});
                    }
                  } catch (e) {
                    debugPrint('Error picking image from camera: $e');
                    _showSnackBar('Failed to open camera: $e. Please rebuild the app.', isError: true);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog() {
    final profile = AuthState().userProfile ?? {};
    final nameController = TextEditingController(text: profile['name'] ?? '');
    final emailController = TextEditingController(text: profile['email'] ?? '');
    final mobileController = TextEditingController(text: profile['mobile'] ?? '');
    final formKey = GlobalKey<FormState>();

    _selectedImage = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogState) {
            final String nameInitials = _getInitials(nameController.text.isEmpty ? 'US' : nameController.text);
            final String? userImage = profile['user_image'];

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: const [
                  Icon(Icons.edit_rounded, color: Color(0xFF6366F1)),
                  SizedBox(width: 12),
                  Text(
                    'Edit Profile',
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
                      Center(
                        child: GestureDetector(
                          onTap: () => _pickImage(dialogState),
                          behavior: HitTestBehavior.opaque,
                          child: Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: _selectedImage != null
                                      ? Image.file(
                                          _selectedImage!,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        )
                                      : (userImage != null && userImage.isNotEmpty)
                                          ? Image.network(
                                              userImage.startsWith('http')
                                                  ? userImage
                                                  : 'https://agsdemo.in/emapi/public/assets/images/user_images/$userImage',
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Center(
                                                child: Text(
                                                  nameInitials,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                nameInitials,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6366F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Name',
                          hintText: 'Enter your name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: mobileController,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Mobile',
                          hintText: 'Enter mobile number',
                          prefixIcon: const Icon(Icons.phone_android_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          if (value.trim().length != 10) {
                            return 'Enter a valid 10-digit mobile number';
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
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                dialogState(() {
                                  _isLoading = true;
                                });
                                try {
                                  final token = AuthState().token ?? '';
                                  final updatedProfile = await _apiService.updateProfile(
                                    token: token,
                                    name: nameController.text.trim(),
                                    mobile: mobileController.text.trim(),
                                    email: emailController.text.trim(),
                                    imagePath: _selectedImage?.path,
                                  );

                                  if (updatedProfile != null) {
                                    await AuthState().saveLogin(token, updatedProfile);
                                  } else {
                                    final refreshed = await _apiService.fetchProfile(token);
                                    await AuthState().saveLogin(token, refreshed);
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _showSnackBar('Profile updated successfully');
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
                                    _isLoading = false;
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
                        child: _isLoading
                            ? const SizedBox(
                                width: 10,
                                height: 5,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
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
  Widget _buildProfileHeaderCard({
    required BuildContext context,
    required String userName,
    required String? userImage,
  }) {
    final String initials = userName.isNotEmpty 
        ? (userName.length >= 2 ? userName.substring(0, 2).toUpperCase() : userName[0].toUpperCase()) 
        : 'US';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:  const Color(0xFF6366F1),
          width: 3.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showEditProfileDialog,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6366F1),
                  width: 2.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: (userImage != null && userImage.isNotEmpty)
                    ? Image.network(
                        userImage.startsWith('http')
                            ? userImage
                            : 'https://agsdemo.in/emapi/public/assets/images/user_images/$userImage',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AuthState().userProfile?['email'] ?? 'No Email',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF6366F1), size: 20),
            onPressed: _showEditProfileDialog,
            tooltip: 'Edit Profile',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingLeadsRaw = _getFilteredLeads('pending');
    final followLeadsRaw = _getFilteredLeads('follow');
    final completedLeads = _getFilteredLeads('completed');

    final pendingLeads = _applyPendingDateFilter(pendingLeadsRaw);
    final followLeads = _applyFollowDateFilter(followLeadsRaw);

    final String userName = AuthState().userProfile?['name'] ?? AuthState().userProfile?['username'] ?? 'User';
    final String? userImage = AuthState().userProfile?['user_image'];

    // Calculate dates & counts for sub-statuses
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    // Pending sub-status counts
    int pendingTodayCount = 0;
    int pendingYesterdayCount = 0;
    int pendingOlderCount = 0;
    for (var lead in pendingLeadsRaw) {
      try {
        final d = DateTime.parse(lead.dataCreated.trim());
        final dayOfD = DateTime(d.year, d.month, d.day);
        if (dayOfD.year == today.year && dayOfD.month == today.month && dayOfD.day == today.day) {
          pendingTodayCount++;
        } else if (dayOfD.year == yesterday.year && dayOfD.month == yesterday.month && dayOfD.day == yesterday.day) {
          pendingYesterdayCount++;
        } else if (dayOfD.isBefore(yesterday)) {
          pendingOlderCount++;
        }
      } catch (_) {}
    }

    // Follow Up sub-status counts
    int followTodayCount = 0;
    int followTomorrowCount = 0;
    int followExpiredCount = 0;
    for (var lead in followLeadsRaw) {
      try {
        if (lead.followupDate != null) {
          final d = DateTime.parse(lead.followupDate!.trim());
          final dayOfD = DateTime(d.year, d.month, d.day);
          if (dayOfD.year == today.year && dayOfD.month == today.month && dayOfD.day == today.day) {
            followTodayCount++;
          } else if (dayOfD.year == tomorrow.year && dayOfD.month == tomorrow.month && dayOfD.day == tomorrow.day) {
            followTomorrowCount++;
          } else if (dayOfD.isBefore(today)) {
            followExpiredCount++;
          }
        }
      } catch (_) {}
    }

    // Calculate total today follow-ups count (unfiltered by search query or sub-status tabs)
    int totalFollowTodayCount = 0;
    for (var lead in _leads) {
      final s = lead.dataStatus.trim().toLowerCase();
      if (s == 'follow up' || s == 'follow') {
        try {
          if (lead.followupDate != null) {
            final d = DateTime.parse(lead.followupDate!.trim());
            final dayOfD = DateTime(d.year, d.month, d.day);
            if (dayOfD.year == today.year && dayOfD.month == today.month && dayOfD.day == today.day) {
              totalFollowTodayCount++;
            }
          }
        } catch (_) {}
      }
    }

    // Dynamic theme color selection matching mockup tabs
    Color activeThemeColor = const Color(0xFFD97706); // Amber/Yellow for Pending
    if (_tabController.index == 1) {
      activeThemeColor = const Color(0xFF3B82F6); // Blue for Follow Up
    } else if (_tabController.index == 2) {
      activeThemeColor = const Color(0xFF10B981); // Green for Completed
    } else if (_tabController.index == 3) {
      activeThemeColor = const Color(0xFF6366F1); // Indigo for Profile
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background layout: Colored header Container + White panel content Container
          Column(
            children: [
              // 1. Dynamic Colored Header Background
              Container(
                height: MediaQuery.of(context).padding.top + 125,
                width: double.infinity,
                color: activeThemeColor,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tabController.index == 0
                                  ? 'Hello, $userName 👋'
                                  : _tabController.index == 1
                                      ? 'Follow Up'
                                      : _tabController.index == 2
                                          ? 'Completed'
                                          : 'Profile',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _tabController.index == 0
                                  ? 'Track and manage your pending leads'
                                  : _tabController.index == 1
                                      ? 'Upcoming follow-ups scheduled'
                                      : _tabController.index == 2
                                          ? 'All leads with their final status'
                                          : 'Manage your CRM account and stats',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Notification bell with badge "8"
                            
                            const SizedBox(width: 8),
                            // Smiling avatar on right
                        if (_tabController.index != 3)
                          GestureDetector(
                            onTap: () {
                              _tabController.animateTo(3); // Switch to Profile tab
                            },
                            
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                             
                              child: (userImage != null && userImage.isNotEmpty)
                                  ? Image.network(
                                      userImage.startsWith('http')
                                          ? userImage
                                          : 'https://agsdemo.in/emapi/public/assets/images/user_images/$userImage',
                                      width: 55,
                                      height: 55,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => CircleAvatar(
                                        radius: 19,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        child: Text(
                                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: 19,
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      child: Text(
                                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          ],
                        ),
                      ],
                    ),
                   
                    
                    // Dynamic Greeting & Subtitle Row
                   
                  
                  ],
                ),
              ),

              // 2. White Panel Content Container
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Spacer to prevent layout collision with overlapping cards sitting above!
                      SizedBox(height: _tabController.index == 3 ? 75 : 40),

                      if (_tabController.index != 3 && _useCommonDetails)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF34A853).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF137333), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Common Message is ON',
                                  style: TextStyle(
                                    color: Color(0xFF137333),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_tabController.index != 3)
                        // Search and Tune Filter Row (without segmented TabBar)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: AppTheme.textPrimary),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: _tabController.index == 0 
                                        ? 'Search pending leads...' 
                                        : _tabController.index == 1 
                                            ? 'Search follow-up leads...' 
                                            : 'Search completed leads...',
                                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchQuery = '';
                                              });
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: activeThemeColor, width: 1.2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.tune_rounded, color: Color(0xFF475569)),
                                  onPressed: _showSortOptionsSheet,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Tab Views
                      Expanded(
                        child: _isLoading
                            ? Center(
                                child: CircularProgressIndicator(color: activeThemeColor),
                              )
                            : TabBarView(
                                controller: _tabController,
                                children: [
                                  PendingTab(
                                    leads: pendingLeads,
                                    todayFollowUpsCount: totalFollowTodayCount,
                                    onCall: (lead) => _makePhoneCall(lead.mobileNo),
                                    onWhatsApp: _openWhatsApp,
                                    onEmail: _promptEmailAndLaunch,
                                    onSchedule: _updateFollowupDateTime,
                                    onChangeStatus: _openStatusSelector,
                                    onViewAttachment: _viewAttachment,
                                    onRefresh: _loadData,
                                    useCommonDetails: _useCommonDetails,
                                    commonMessage: _commonMessage,
                                    commonImagePath: _commonImagePath,
                                  ),
                                  FollowTab(
                                    leads: followLeads,
                                    onCall: (lead) => _makePhoneCall(lead.mobileNo),
                                    onWhatsApp: _openWhatsApp,
                                    onEmail: _promptEmailAndLaunch,
                                    onSchedule: _updateFollowupDateTime,
                                    onChangeStatus: _openStatusSelector,
                                    onViewAttachment: _viewAttachment,
                                    onRefresh: _loadData,
                                    useCommonDetails: _useCommonDetails,
                                    commonMessage: _commonMessage,
                                    commonImagePath: _commonImagePath,
                                  ),
                                  CompletedTab(
                                    leads: completedLeads,
                                    statuses: _statuses,
                                    activeSubStatus: _activeCompletedSubStatus,
                                    onSubStatusChanged: (status) {
                                      setState(() {
                                        _activeCompletedSubStatus = status;
                                      });
                                    },
                                    onCall: (lead) => _makePhoneCall(lead.mobileNo),
                                    onWhatsApp: _openWhatsApp,
                                    onEmail: _promptEmailAndLaunch,
                                    onSchedule: _updateFollowupDateTime,
                                    onChangeStatus: _openStatusSelector,
                                    onViewAttachment: _viewAttachment,
                                    onRefresh: _loadData,
                                    useCommonDetails: _useCommonDetails,
                                    commonMessage: _commonMessage,
                                    commonImagePath: _commonImagePath,
                                  ),
                                  ProfileTab(
                                    onLogout: _showLogoutConfirmation,
                                    pendingCount: pendingLeadsRaw.length,
                                    followCount: followLeadsRaw.length,
                                    completedCount: completedLeads.length,
                                    onSettingsChanged: _loadCommonSettings,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Overlapping Count Cards Row positioned exactly on the color/white boundary
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 20,
            right: 20,
            child: _tabController.index == 0
                // 1. Pending Tab Sub-status Cards
                ? Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildTabAllCard(
                          title: 'All',
                          count: pendingLeadsRaw.length,
                          isActive: _activePendingSubStatus == 'all',
                          activeColor: const Color(0xFFD97706),
                          onTap: () {
                            setState(() {
                              _activePendingSubStatus = 'all';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              children: [
                                _buildGroupedItem(
                                  title: 'Today',
                                  count: pendingTodayCount,
                                  isActive: _activePendingSubStatus == 'today',
                                  icon: Icons.today_rounded,
                                  iconColor: const Color(0xFFD97706),
                                  onTap: () {
                                    setState(() {
                                      _activePendingSubStatus = 'today';
                                    });
                                  },
                                ),
                                _buildVerticalDivider(),
                                _buildGroupedItem(
                                  title: 'Yesterday',
                                  count: pendingYesterdayCount,
                                  isActive: _activePendingSubStatus == 'yesterday',
                                  icon: Icons.history_rounded,
                                  iconColor: const Color(0xFF64748B),
                                  onTap: () {
                                    setState(() {
                                      _activePendingSubStatus = 'yesterday';
                                    });
                                  },
                                ),
                                _buildVerticalDivider(),
                                _buildGroupedItem(
                                  title: 'Older',
                                  count: pendingOlderCount,
                                  isActive: _activePendingSubStatus == 'older',
                                  icon: Icons.calendar_month_rounded,
                                  iconColor: const Color(0xFF475569),
                                  onTap: () {
                                    setState(() {
                                      _activePendingSubStatus = 'older';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _tabController.index == 1
                    // 2. Follow Up Tab Sub-status Cards
                    ? Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildTabAllCard(
                              title: 'All',
                              count: followLeadsRaw.length,
                              isActive: _activeFollowSubStatus == 'all',
                              activeColor: const Color(0xFF3B82F6),
                              onTap: () {
                                setState(() {
                                  _activeFollowSubStatus = 'all';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                child: Row(
                                  children: [
                                    _buildGroupedItem(
                                      title: 'Today',
                                      count: followTodayCount,
                                      isActive: _activeFollowSubStatus == 'today',
                                      icon: Icons.alarm_rounded,
                                      iconColor: const Color(0xFF3B82F6),
                                      onTap: () {
                                        setState(() {
                                          _activeFollowSubStatus = 'today';
                                        });
                                      },
                                    ),
                                    _buildVerticalDivider(),
                                    _buildGroupedItem(
                                      title: 'Tomorrow',
                                      count: followTomorrowCount,
                                      isActive: _activeFollowSubStatus == 'tomorrow',
                                      icon: Icons.calendar_today_rounded,
                                      iconColor: const Color(0xFF10B981),
                                      onTap: () {
                                        setState(() {
                                          _activeFollowSubStatus = 'tomorrow';
                                        });
                                      },
                                    ),
                                    _buildVerticalDivider(),
                                    _buildGroupedItem(
                                      title: 'Expired',
                                      count: followExpiredCount,
                                      isActive: _activeFollowSubStatus == 'expired',
                                      icon: Icons.warning_amber_rounded,
                                      iconColor: const Color(0xFFEF4444),
                                      onTap: () {
                                        setState(() {
                                          _activeFollowSubStatus = 'expired';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                : _tabController.index == 2
                    // 3. Completed Tab Sub-status Cards
                    ? Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildTabAllCard(
                              title: 'All',
                              count: completedLeads.length,
                              isActive: _activeCompletedSubStatus == 'all',
                              activeColor: const Color(0xFF10B981),
                              onTap: () {
                                setState(() {
                                  _activeCompletedSubStatus = 'all';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                child: Row(
                                  children: [
                                    _buildGroupedItem(
                                      title: 'Completed',
                                      count: completedLeads.where((l) => l.dataStatus.toLowerCase().trim() == 'completed').length,
                                      isActive: _activeCompletedSubStatus == 'completed',
                                      icon: Icons.check_circle_rounded,
                                      iconColor: const Color(0xFF10B981),
                                      onTap: () {
                                        setState(() {
                                          _activeCompletedSubStatus = 'completed';
                                        });
                                      },
                                    ),
                                    _buildVerticalDivider(),
                                    _buildGroupedItem(
                                      title: 'Wrong No.',
                                      count: completedLeads.where((l) {
                                        final s = l.dataStatus.toLowerCase().trim();
                                        return s == 'wrong number' || s == 'wrong no.';
                                      }).length,
                                      isActive: _activeCompletedSubStatus == 'wrong no.',
                                      icon: Icons.phone_disabled_rounded,
                                      iconColor: const Color(0xFFEF4444),
                                      onTap: () {
                                        setState(() {
                                          _activeCompletedSubStatus = 'wrong no.';
                                        });
                                      },
                                    ),
                                    _buildVerticalDivider(),
                                    _buildGroupedItem(
                                      title: 'Switch Off',
                                      count: completedLeads.where((l) => l.dataStatus.toLowerCase().trim() == 'switch off').length,
                                      isActive: _activeCompletedSubStatus == 'switch off',
                                      icon: Icons.power_settings_new_rounded,
                                      iconColor: const Color(0xFFF59E0B),
                                      onTap: () {
                                        setState(() {
                                          _activeCompletedSubStatus = 'switch off';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildProfileHeaderCard(
                        context: context,
                        userName: userName,
                        userImage: userImage,
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: BottomNavigationBar(
              currentIndex: _tabController.index,
              onTap: (index) {
                _tabController.animateTo(index);
              },
              backgroundColor: Colors.white,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: activeThemeColor,
              unselectedItemColor: const Color(0xFF94A3B8),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              items: [
                BottomNavigationBarItem(
                  icon: _buildBottomBarIcon(Icons.pending_actions_rounded, _tabController.index == 0, const Color(0xFFD97706)),
                  label: 'Pending',
                ),
                BottomNavigationBarItem(
                  icon: _buildBottomBarIcon(Icons.alarm_rounded, _tabController.index == 1, const Color(0xFF3B82F6)),
                  label: 'Follow Up',
                ),
                BottomNavigationBarItem(
                  icon: _buildBottomBarIcon(Icons.check_circle_rounded, _tabController.index == 2, const Color(0xFF10B981)),
                  label: 'Completed',
                ),
                BottomNavigationBarItem(
                  icon: _buildBottomBarIcon(Icons.person_rounded, _tabController.index == 3, const Color(0xFF6366F1)),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
