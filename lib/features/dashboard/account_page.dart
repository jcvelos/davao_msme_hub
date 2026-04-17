import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userMetadata;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          _userMetadata = user.userMetadata;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildProfileSection(user),
              const SizedBox(height: 20),
              _buildAccountDetails(user),
              const SizedBox(height: 20),
              _buildSettingsSection(),
              const SizedBox(height: 30),
              _buildSignOutButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[700]!, Colors.green[500]!],
        ),
      ),
      child: Column(
        children: [
          const Text(
            "My Account",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Manage your profile and preferences",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(User? user) {
    final String rawName = _userMetadata?['full_name'] as String? ?? 
                         _userMetadata?['name'] as String? ?? 
                         user?.email?.split('@').first ?? 
                         'User';
    
    final displayName = rawName.trim().isEmpty ? 'User' : rawName;
    
    final profilePicture = _userMetadata?['avatar_url'] as String? ?? 
                           _userMetadata?['picture'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.green[100],
            backgroundImage: profilePicture != null ? NetworkImage(profilePicture) : null,
            child: profilePicture == null
                ? Text(
                    displayName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'No email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildBadge(user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(User? user) {
    final isAnonymous = user?.isAnonymous ?? true;
    final provider = user?.appMetadata['provider'] as String? ?? 'email';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAnonymous ? Colors.grey[200] : Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAnonymous ? Colors.grey[400]! : Colors.green[200]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAnonymous ? Icons.visibility_off : _getProviderIcon(provider),
            size: 14,
            color: isAnonymous ? Colors.grey[700] : Colors.green[700],
          ),
          const SizedBox(width: 4),
          Text(
            isAnonymous ? "Guest User" : _getProviderName(provider),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isAnonymous ? Colors.grey[700] : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return Icons.g_mobiledata;
      case 'email':
        return Icons.email;
      default:
        return Icons.account_circle;
    }
  }

  String _getProviderName(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return "Google Account";
      case 'email':
        return "Email Account";
      default:
        return "Account";
    }
  }

  Widget _buildAccountDetails(User? user) {
    final createdAt = user?.createdAt;
    final lastSignIn = user?.lastSignInAt;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Account Details",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            icon: Icons.fingerprint,
            label: "User ID",
            value: user?.id.substring(0, 8) ?? 'N/A',
          ),
          const Divider(height: 24),
          _buildDetailRow(
            icon: Icons.phone_android,
            label: "Phone",
            value: user?.phone ?? 'Not provided',
          ),
          const Divider(height: 24),
          _buildDetailRow(
            icon: Icons.calendar_today,
            label: "Member Since",
            value: createdAt != null 
                ? _formatDate(DateTime.parse(createdAt)) // Parse the string here
                : 'Unknown',
          ),
          const Divider(height: 24),
          _buildDetailRow(
            icon: Icons.access_time,
            label: "Last Sign In",
            value: lastSignIn != null 
                ? _formatDate(DateTime.parse(lastSignIn)) // And here
                : 'Unknown',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.edit,
            title: "Edit Profile",
            subtitle: "Update your personal information",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile editing coming soon!")),
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: "Notifications",
            subtitle: "Manage notification preferences",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Notification settings coming soon!")),
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: "Privacy & Security",
            subtitle: "Manage your privacy settings",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Privacy settings coming soon!")),
              );
            },
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: "Help & Support",
            subtitle: "Get help or contact support",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Support page coming soon!")),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.green[700], size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _handleSignOut,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text(
            "Sign Out",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return "$weeks ${weeks == 1 ? 'week' : 'weeks'} ago";
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return "$months ${months == 1 ? 'month' : 'months'} ago";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}