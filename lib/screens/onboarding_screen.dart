import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../main.dart';
import '../layout/main_layout.dart';
import '../packet/get_user_name.dart';
import 'scanner_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  UserRole? _selectedRole;
  final TextEditingController _nameController = TextEditingController();
  bool _rescuerAuthenticated = false;

  void _nextPage() {
    FocusScope.of(context).unfocus();

    final totalPages = _selectedRole == UserRole.rescuer ? 4 : 3;

    if (_selectedRole == UserRole.rescuer && _currentPage == 2 && !_rescuerAuthenticated) {
      // Must authenticate before proceeding from the Auth page
      _scanRescuerToken();
      return;
    }
    
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _scanRescuerToken() async {
    // If they already scanned, proceed
    if (_rescuerAuthenticated) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    // After returning from ScannerScreen, check if they successfully authenticated
    if (success == true) {
      setState(() {
        _rescuerAuthenticated = true;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefHasCompletedOnboarding, true);
    
    if (_nameController.text.trim().isNotEmpty) {
      await UserSettings.setName(_nameController.text.trim());
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainLayout()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeaconColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Prevent swipe to skip validation
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildRoleSelectionPage(),
                  _buildNameInputPage(),
                  if (_selectedRole == UserRole.rescuer)
                    _buildRescuerAuthPage()
                  else
                    _buildFeatureTourUser(),
                  if (_selectedRole == UserRole.rescuer)
                    _buildFeatureTourRescuer(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.satellite_alt_rounded, size: 80, color: BeaconColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Welcome to Beacon',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: BeaconColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'How will you be using this app?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: BeaconColors.textMid),
          ),
          const SizedBox(height: 48),
          _RoleCard(
            title: 'Civilian / Need Help',
            description: 'I want to ask for help, communicate off-grid, and monitor the area.',
            icon: Icons.person_rounded,
            isSelected: _selectedRole == UserRole.user,
            onTap: () {
              setState(() => _selectedRole = UserRole.user);
              AppState().role.value = UserRole.user;
            },
          ),
          const SizedBox(height: 16),
          _RoleCard(
            title: 'First Responder',
            description: 'I want to receive alerts, locate victims, and coordinate rescue missions.',
            icon: Icons.local_police_rounded,
            isSelected: _selectedRole == UserRole.rescuer,
            onTap: () {
              setState(() => _selectedRole = UserRole.rescuer);
              AppState().role.value = UserRole.rescuer;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNameInputPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.badge_rounded, size: 80, color: BeaconColors.primary),
          const SizedBox(height: 24),
          const Text(
            'What should we call you?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: BeaconColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This name will be visible to nearby devices in the mesh network.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: BeaconColors.textMid),
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'Enter your full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }

  Widget _buildRescuerAuthPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.qr_code_scanner_rounded, size: 80, color: BeaconColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Rescuer Authentication',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: BeaconColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Please scan your official responder QR code to access the command dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: BeaconColors.textMid),
          ),
          const SizedBox(height: 48),
          if (_rescuerAuthenticated)
            const Column(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text(
                  'Authentication verified!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: _scanRescuerToken,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BeaconColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureTourUser() {
    return _buildTourLayout(
      title: 'How to use Beacon',
      features: const [
        _FeatureSpec(icon: Icons.sos_rounded, title: 'Request Help', text: 'Use the SOS button on the main screen to alert nearby responders.'),
        _FeatureSpec(icon: Icons.home_rounded, title: 'Home', text: 'View important announcements from nearby responders and authorities.'),
        _FeatureSpec(icon: Icons.chat_bubble_rounded, title: 'Off-grid Chat', text: 'Chat with people around you without internet or cell service.'),
        _FeatureSpec(icon: Icons.map_rounded, title: 'Offline Maps', text: 'View users in your area directly on your device.'),
      ],
    );
  }

  Widget _buildFeatureTourRescuer() {
    return _buildTourLayout(
      title: 'Responder Dashboard',
      features: const [
        _FeatureSpec(icon: Icons.map_rounded, title: 'SOS Heatmap', text: 'Locate distress beacons securely over the mesh network.'),
        _FeatureSpec(icon: Icons.home_rounded, title: 'Home', text: 'View important announcements from nearby responders and authorities.'),
        _FeatureSpec(icon: Icons.chat_bubble_rounded, title: 'Coordination', text: 'Chat with other responders and civilians in the local mesh.'),
      ],
    );
  }

  Widget _buildTourLayout({required String title, required List<_FeatureSpec> features}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: BeaconColors.textDark,
            ),
          ),
          const SizedBox(height: 32),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BeaconColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(f.icon, color: BeaconColors.primary, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BeaconColors.textDark)),
                      const SizedBox(height: 4),
                      Text(f.text, style: const TextStyle(fontSize: 14, color: BeaconColors.textMid)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    bool canProceed = true;
    if (_currentPage == 0 && _selectedRole == null) canProceed = false;
    if (_currentPage == 1 && _nameController.text.trim().isEmpty) canProceed = false;
    
    // We only have 3 pages for User/Victim, and 4 pages for Rescuer.
    // Let's cap _currentPage accordingly if we used length.
    final totalPages = _selectedRole == UserRole.rescuer ? 4 : 3;
    final isLastPage = _currentPage == (totalPages - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: _previousPage,
              child: const Text('Back', style: TextStyle(color: BeaconColors.textMid, fontSize: 16)),
            )
          else
            const SizedBox(width: 60),

          // Dots indicator
          Row(
            children: List.generate(totalPages, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? BeaconColors.primary : BeaconColors.cardBorder,
                ),
              );
            }),
          ),

          ElevatedButton(
            onPressed: canProceed ? _nextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: BeaconColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              isLastPage ? 'Let\'s Go!' : 'Next',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? BeaconColors.primary.withOpacity(0.05) : BeaconColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? BeaconColors.primary : BeaconColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? BeaconColors.primary : BeaconColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : BeaconColors.textMid),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? BeaconColors.primary : BeaconColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: BeaconColors.textMid),
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

class _FeatureSpec {
  final IconData icon;
  final String title;
  final String text;

  const _FeatureSpec({required this.icon, required this.title, required this.text});
}
