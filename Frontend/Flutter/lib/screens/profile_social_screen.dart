import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lattice/themes/app_colors.dart';

class ProfileSocialScreen extends StatefulWidget {
  const ProfileSocialScreen({super.key});

  @override
  State<ProfileSocialScreen> createState() => _ProfileSocialScreenState();
}

class _ProfileSocialScreenState extends State<ProfileSocialScreen> {
  static const String _myFriendCode = 'LATTICE-8X2P';

  final TextEditingController _friendCodeController = TextEditingController();
  bool _isAddFriendsExpanded = false;

  final List<_FriendData> _friends = [
    const _FriendData(
      name: 'Kade Shockey',
      handle: '@kirex',
      streak: 8,
      currentTask: 'Build an evening reading habit',
      completedDays: 8,
      totalDays: 30,
      accentColor: Color(0xFF5FD3BC),
    ),
    const _FriendData(
      name: 'Vincent Cordova',
      handle: '@vlvc',
      streak: 14,
      currentTask: 'Ship a portfolio refresh',
      completedDays: 18,
      totalDays: 30,
      accentColor: Color(0xFFFFB86B),
    ),
    const _FriendData(
      name: 'Cece Housh',
      handle: '@cecehoush',
      streak: 5,
      currentTask: 'Morning workout consistency',
      completedDays: 8,
      totalDays: 30,
      accentColor: Color(0xFF89BBFE),
    ),
    const _FriendData(
      name: 'Jeffer Ng',
      handle: '@jefferng',
      streak: 22,
      currentTask: 'Daily system design practice',
      completedDays: 24,
      totalDays: 30,
      accentColor: Color(0xFFE886C9),
    ),
  ];

  @override
  void dispose() {
    _friendCodeController.dispose();
    super.dispose();
  }

  void _copyFriendCode() {
    Clipboard.setData(const ClipboardData(text: _myFriendCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Friend code copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _submitFriendCode() {
    final code = _friendCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a friend code to add someone'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Friend request sent with code $code'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _friendCodeController.clear();
  }

  void _removeFriend(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name removed from friends'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _QrScannerScreen(
          onCodeScanned: (code) {
            Navigator.of(context).pop();
            _friendCodeController.text = code;
            _submitFriendCode();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAddFriendsCard(),
          const SizedBox(height: 28),
          _buildFriendsHeader(),
          const SizedBox(height: 16),
          ..._friends.map(
            (friend) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _FriendTile(
                friend: friend,
                onRemove: () => _removeFriend(friend.name),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFriendsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: _isAddFriendsExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _isAddFriendsExpanded = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          iconColor: AppColors.textPrimary,
          collapsedIconColor: AppColors.textPrimary,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.activeTab.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'ADD FRIENDS',
                  style: TextStyle(
                    color: AppColors.activeTab,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'How to add friends',
                child: GestureDetector(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: const BorderSide(color: AppColors.cardBorder),
                        ),
                        title: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.activeTab,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'How adding works',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        content: const Text(
                          'Share your code, paste theirs below, or scan a QR code to connect instantly!',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Close',
                              style: TextStyle(color: AppColors.activeTab),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                _isAddFriendsExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textPrimary,
              ),
            ],
          ),
          children: [
            Center(
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.activeTab.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.activeTab.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: QrImageView(
                  data: _myFriendCode,
                  version: QrVersions.auto,
                  size: 174,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: AppColors.textPrimary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: AppColors.textPrimary,
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openQrScanner,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.activeTab,
                  side: const BorderSide(color: AppColors.activeTab),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text(
                  'Scan QR Code',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildFriendCodeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your friend code',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  _myFriendCode,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _copyFriendCode,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.activeTab,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Text(
              'Enter a friend code',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Friend code info',
              child: GestureDetector(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(color: AppColors.cardBorder),
                      ),
                      title: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.activeTab,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Friend codes',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      content: const Text(
                        'Paste a code someone shared with you to send them a friend request.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: AppColors.activeTab),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _friendCodeController,
          cursorColor: AppColors.textPrimary,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter code',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.activeTab),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitFriendCode,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Send Friend Request',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsHeader() {
    return Row(
      children: [
        const Text(
          'Friends list',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Friends list info',
          child: GestureDetector(
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  title: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.activeTab,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Friends list',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  content: const Text(
                    'Open each friend card to view their current streak, active task, progress, or remove them.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: AppColors.activeTab),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.onRemove,
  });

  final _FriendData friend;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final double progressValue = friend.completedDays / friend.totalDays;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          iconColor: AppColors.textPrimary,
          collapsedIconColor: AppColors.textPrimary,
          title: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: friend.accentColor.withValues(alpha: 0.18),
                child: Text(
                  friend.name.characters.first,
                  style: TextStyle(
                    color: friend.accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friend.handle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: friend.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${friend.streak} streak',
                  style: TextStyle(
                    color: friend.accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StatPill(
                        label: 'Current streak',
                        value: '${friend.streak}',
                        accentColor: friend.accentColor,
                        icon: Icons.local_fire_department_rounded,
                      ),
                      _StatPill(
                        label: 'Progress',
                        value: '${friend.completedDays}/${friend.totalDays}',
                        accentColor: AppColors.activeTab,
                        icon: Icons.insights_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Current task',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    friend.currentTask,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        friend.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${friend.completedDays}/${friend.totalDays} progress, with ${friend.streak} streak',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF8A80),
                      side: const BorderSide(color: Color(0x55FF8A80)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.person_remove_alt_1_rounded),
                    label: const Text(
                      'Remove friend',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen({required this.onCodeScanned});

  final ValueChanged<String> onCodeScanned;

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Scan Friend Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode == null) return;
              final code = barcode.rawValue;
              if (code != null && code.toUpperCase().startsWith('LATTICE-')) {
                _hasScanned = true;
                widget.onCodeScanned(code.toUpperCase());
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.activeTab.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Point at a friend\'s QR code',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendData {
  const _FriendData({
    required this.name,
    required this.handle,
    required this.streak,
    required this.currentTask,
    required this.completedDays,
    required this.totalDays,
    required this.accentColor,
  });

  final String name;
  final String handle;
  final int streak;
  final String currentTask;
  final int completedDays;
  final int totalDays;
  final Color accentColor;
}
