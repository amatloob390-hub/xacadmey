import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../widgets/theme_selector.dart';
import 'auth_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _useCaseKey = GlobalKey();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _whyUsKey = GlobalKey();
  final GlobalKey _plansKey = GlobalKey();

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToAuth({bool isSignUp = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthScreen(initialIsSignUp: isSignUp),
      ),
    );
  }

  void _scrollBy(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openSocialUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  TextStyle _ts({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    ThemePreset? theme,
  }) {
    final defaultColor = theme != null ? theme.textColor : const Color(0xFF1E293B);
    final defaultHeight = AppLang.ur ? 2.0 : 1.6;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? defaultColor,
      height: height ?? defaultHeight,
      fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
    );
  }

  // --- BRAND LOGO ---
  Widget _buildBrandLogo({required ThemePreset theme, bool compact = false}) {
    return InkWell(
      onTap: () {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.secondaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: compact ? 20 : 24,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'X ',
                    style: _ts(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: theme.textColor,
                    ),
                  ),
                  TextSpan(
                    text: 'ACADEMY',
                    style: _ts(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLang.isUrdu,
      builder: (context, urdu, _) {
        return ValueListenableBuilder<ThemePreset>(
          valueListenable: AppTheme.currentTheme,
          builder: (context, theme, _) {
            final isWide = MediaQuery.of(context).size.width > 900;
            final session = Supabase.instance.client.auth.currentSession;
            final isLoggedIn = session != null;

            return Scaffold(
              backgroundColor: theme.bgColor,
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(isWide ? 75 : 62),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: theme.isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 24 : 14,
                        vertical: isWide ? 10 : 8,
                      ),
                      child: Row(
                        children: [
                          // 1. Logo — full on wide, icon-only on mobile
                          _buildBrandLogo(theme: theme, compact: !isWide),

                          const Spacer(),

                          // 2. Navigation Menu Links (wide screens only)
                          if (isWide) ...[
                            _buildHeaderLink(
                              theme: theme,
                              label: L.t('کن کے لیے', 'For Whom?'),
                              onTap: () => _scrollToSection(_useCaseKey),
                            ),
                            const SizedBox(width: 16),
                            _buildHeaderLink(
                              theme: theme,
                              label: L.t('طریقہ کار', 'How It Works'),
                              onTap: () => _scrollToSection(_howItWorksKey),
                            ),
                            const SizedBox(width: 16),
                            _buildHeaderLink(
                              theme: theme,
                              label: L.t('ہم ہی کیوں؟', 'Why Us?'),
                              onTap: () => _scrollToSection(_whyUsKey),
                            ),
                            const SizedBox(width: 16),
                            _buildHeaderLink(
                              theme: theme,
                              label: L.t('پلانز', 'Plans'),
                              onTap: () => _scrollToSection(_plansKey),
                            ),
                            const SizedBox(width: 20),
                          ],

                          // 3. Language Switcher (compact icon-only on mobile)
                          if (isWide)
                            const LanguageToggle()
                          else
                            const CompactLanguageToggle(),
                          const SizedBox(width: 6),
                          const ThemeSelectorButton(),
                          const SizedBox(width: 8),

                          // 4. Action Button
                          if (isLoggedIn) ...[
                            ElevatedButton.icon(
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                              icon: Icon(Icons.dashboard_rounded, size: isWide ? 18 : 16),
                              label: Text(
                                L.t('ڈیش بورڈ', isWide ? 'Dashboard' : 'Dash'),
                                style: _ts(
                                  fontSize: isWide ? 14 : 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWide ? 18 : 10,
                                  vertical: isWide ? 12 : 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ] else ...[
                            if (isWide)
                              TextButton(
                                onPressed: () => _navigateToAuth(isSignUp: false),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.textColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                child: Text(
                                  L.t('لاگ اِن', 'Login'),
                                  style: _ts(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textColor,
                                  ),
                                ),
                              ),
                            if (isWide) const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _navigateToAuth(isSignUp: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: theme.primaryColor.withValues(alpha: 0.4),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWide ? 22 : 14,
                                  vertical: isWide ? 14 : 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                L.t('مفت ٹرائل', isWide ? 'Start Free Trial' : 'Sign Up'),
                                style: _ts(
                                  fontSize: isWide ? 15 : 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              body: KeyboardListener(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: (event) {
                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _scrollBy(150);
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _scrollBy(-150);
                    } else if (event.logicalKey == LogicalKeyboardKey.space ||
                        event.logicalKey == LogicalKeyboardKey.pageDown) {
                      _scrollBy(450);
                    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
                      _scrollBy(-450);
                    }
                  }
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      // 1. HERO SECTION
                      _buildHeroSection(theme, isWide, isLoggedIn),

                      const SizedBox(height: 60),

                      // 2. TARGET AUDIENCE / USE-CASE CARDS SECTION
                      Container(
                        key: _useCaseKey,
                        child: _buildUseCaseCardsSection(theme, isWide),
                      ),

                      const SizedBox(height: 80),

                      // 3. HOW IT WORKS SECTION
                      Container(
                        key: _howItWorksKey,
                        child: _buildHowItWorksSection(theme, isWide),
                      ),

                      const SizedBox(height: 80),

                      // 4. WHY US / CORE FEATURES SECTION
                      Container(
                        key: _whyUsKey,
                        child: _buildFeaturesSection(theme, isWide),
                      ),

                      const SizedBox(height: 80),

                      // 5. PLANS SECTION
                      Container(
                        key: _plansKey,
                        child: _buildPlansSection(theme, isWide, isLoggedIn),
                      ),

                      const SizedBox(height: 80),

                      // 6. CALL TO ACTION BANNER
                      _buildCtaBanner(theme, isLoggedIn, isWide),

                      const SizedBox(height: 60),

                      // 7. MULTI-COLUMN RESPONSIVE FOOTER
                      _buildFooter(theme, isWide),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderLink({
    required ThemePreset theme,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: _ts(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
      ),
    );
  }

  // --- 1. HERO SECTION (UNIFIED 4-SLIDE FULL-WIDTH 3D CAROUSEL) ---
  Widget _buildHeroSection(ThemePreset theme, bool isWide, bool isLoggedIn) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: isWide ? 20 : 10,
        vertical: isWide ? 16 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Background 3D Graphic Image Overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(
                  'assets/hero_3d_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),

            // 1. FULL-SCREEN EDGE-TO-EDGE HERO 3D SLIDER (BACKGROUND / MIDDLE LAYER)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 0,
                vertical: isWide ? 30 : 16,
              ),
              child: Hero3DSlider(
                theme: theme,
                isLoggedIn: isLoggedIn,
                onNavigateToAuth: () => _navigateToAuth(isSignUp: false),
                onNavigateToSignUp: () => _navigateToAuth(isSignUp: true),
                onScrollToHowItWorks: () => _scrollToSection(_howItWorksKey),
              ),
            ),

            // 2. High-Visibility Floating 3D AI Memojis / Emojis (TOP FOREGROUND LAYER - LARGER SIZE)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    // Top-Left Floating AI Robot Memoji (Cross Rotates towards Bottom-Right)
                    Positioned(
                      left: isWide ? 35 : 10,
                      top: isWide ? 20 : 10,
                      child: Floating3DAIEmojiWidget(
                        imagePath: 'assets/ai_memoji_robot.png',
                        fallbackIcon: Icons.smart_toy_rounded,
                        label: 'AI Robot',
                        size: isWide ? 140 : 85,
                        duration: const Duration(seconds: 4),
                        maxTranslationX: isWide ? 95.0 : 45.0,
                        maxTranslationY: isWide ? 65.0 : 30.0,
                        accentColor: const Color(0xFF00D2FF),
                      ),
                    ),

                    // Bottom-Left Floating AI Cyber Brain (Cross Rotates towards Top-Right)
                    Positioned(
                      left: isWide ? 40 : 10,
                      bottom: isWide ? 20 : 10,
                      child: Floating3DAIEmojiWidget(
                        imagePath: 'assets/ai_cyber_brain.png',
                        fallbackIcon: Icons.psychology_rounded,
                        label: 'Cyber Brain',
                        size: isWide ? 145 : 90,
                        duration: const Duration(milliseconds: 4400),
                        maxTranslationX: isWide ? 95.0 : 45.0,
                        maxTranslationY: isWide ? -65.0 : -30.0,
                        accentColor: const Color(0xFF10B981),
                      ),
                    ),

                    // Top-Right Floating AI Cyber Brain (Cross Rotates towards Bottom-Left)
                    Positioned(
                      right: isWide ? 35 : 10,
                      top: isWide ? 20 : 10,
                      child: Floating3DAIEmojiWidget(
                        imagePath: 'assets/ai_cyber_brain.png',
                        fallbackIcon: Icons.auto_awesome_rounded,
                        label: 'AI Core',
                        size: isWide ? 135 : 85,
                        duration: const Duration(milliseconds: 3800),
                        maxTranslationX: isWide ? -95.0 : -45.0,
                        maxTranslationY: isWide ? 65.0 : 30.0,
                        accentColor: const Color(0xFF7C3AED),
                      ),
                    ),

                    // Bottom-Right Floating AI Robot (Cross Rotates towards Top-Left)
                    Positioned(
                      right: isWide ? 40 : 10,
                      bottom: isWide ? 20 : 10,
                      child: Floating3DAIEmojiWidget(
                        imagePath: 'assets/ai_memoji_robot.png',
                        fallbackIcon: Icons.precision_manufacturing_rounded,
                        label: 'AI Assistant',
                        size: isWide ? 140 : 85,
                        duration: const Duration(milliseconds: 4200),
                        maxTranslationX: isWide ? -95.0 : -45.0,
                        maxTranslationY: isWide ? -65.0 : -30.0,
                        accentColor: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  // --- 2. TARGET AUDIENCE / USE-CASE CARDS SECTION ---
  Widget _buildUseCaseCardsSection(ThemePreset theme, bool isWide) {
    final cards = [
      {
        'icon': Icons.location_on_outlined,
        'titleUrdu': 'کوئی رہنما نہیں؟',
        'titleEn': 'No Mentor Nearby?',
        'descUrdu': 'قریب کوئی اچھا mentor نہیں؟ دنیا کے بہترین freelancing اساتذہ تک آن لائن پہنچیں۔',
        'descEn': 'No good mentor nearby? Reach top freelancing teachers online worldwide.',
      },
      {
        'icon': Icons.access_time_rounded,
        'titleUrdu': 'مصروف اوقات',
        'titleEn': 'Busy Schedule',
        'descUrdu': 'کام، سفر یا مصروف دن؟ جب چاہیں لائیو کلاس جوائن کریں۔ اپنی سہولت کے مطابق سیکھیں۔',
        'descEn': 'Work, travel, or busy day? Join live class whenever you want. Learn at your convenience.',
      },
      {
        'icon': Icons.language_rounded,
        'titleUrdu': 'بیرونِ ملک مقیم',
        'titleEn': 'Living Overseas',
        'descUrdu': 'بیرونِ ملک ہوں؟ گھر بیٹھے عالمی معیار کی اسکلز سیکھیں اور بین الاقوامی کلائنٹس کے لیے کام کرنے کے قابل بنیں۔',
        'descEn': 'Living abroad? Learn world-class skills from home and work for international clients.',
      },
    ];

    Widget buildUseCaseCard(Map<String, dynamic> c) {
      return Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Icon(
                c['icon'] as IconData,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              L.t(c['titleUrdu'] as String, c['titleEn'] as String),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              L.t(c['descUrdu'] as String, c['descEn'] as String),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.7,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1150),
        child: Column(
          children: [
            // PROMINENT SECTION TAG (22pt)
            Text(
              L.t('کن کے لیے', 'FOR WHOM?'),
              style: _ts(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.primaryColor,
                height: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              L.t(
                'اُن سب کے لیے جو آن لائن اسکل سیکھ کر آگے بڑھنا چاہتے ہیں۔',
                'For everyone who wants to learn online skills and move forward.',
              ),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: isWide ? 34 : 24,
                fontWeight: FontWeight.w900,
                color: theme.textColor,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              L.t(
                'فاصلہ، مصروفیت یا مقام، سہولت کی کمی، آپ کے سیکھنے کی راہ میں نہ آئے۔',
                'Distance, busy schedule, or location should not stand in your way of learning.',
              ),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: 16,
                color: theme.subtextColor,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 40),
            if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: buildUseCaseCard(cards[0])),
                    const SizedBox(width: 20),
                    Expanded(child: buildUseCaseCard(cards[1])),
                    const SizedBox(width: 20),
                    Expanded(child: buildUseCaseCard(cards[2])),
                  ],
                ),
              )
            else
              Column(
                children: cards
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: buildUseCaseCard(c),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // --- 3. HOW IT WORKS SECTION ---
  Widget _buildHowItWorksSection(ThemePreset theme, bool isWide) {
    final steps = [
      {
        'num': '1',
        'titleUrdu': 'مفت شروع کریں یا پلان چنیں',
        'titleEn': 'Start Free or Pick a Plan',
        'descUrdu': '7 دن کی ٹرائل کلاسز بالکل مفت۔ مزید چاہیے؟ Paid یا Premier لیں۔ ٹیچر ایک بار آپ کی فیس verify کرے۔',
        'descEn': '7-day trial classes completely free. Need more? Choose Paid or Premier. Teacher verifies your fee once.',
      },
      {
        'num': '2',
        'titleUrdu': 'ایک کلک میں لائیو جوائن',
        'titleEn': 'Join Live in One Click',
        'descUrdu': '"جوائن" کا بٹن دبائیں اور لائیو کلاس فوراً کھل جائے — کسی سیٹ اپ یا الجھن کے بغیر۔',
        'descEn': 'Click "Join" button and your live class opens instantly — with no setup or hassle.',
      },
      {
        'num': '3',
        'titleUrdu': 'AI آپ کے ساتھ',
        'titleEn': 'AI Assistant by Your Side',
        'descUrdu': 'کلاس کے بعد اٹک گئے؟ AI اسسٹنٹ سے وضاحت، پریکٹس اور پروجیکٹ میں مدد لیں — کسی بھی وقت، اپنی زبان میں۔',
        'descEn': 'Stuck after class? Get explanations, practice, and project help from AI Assistant anytime in your language.',
      },
    ];

    Widget buildStepCard(Map<String, dynamic> s) {
      return Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                s['num'] as String,
                style: _ts(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              L.t(s['titleUrdu'] as String, s['titleEn'] as String),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              L.t(s['descUrdu'] as String, s['descEn'] as String),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.7,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1150),
        child: Column(
          children: [
            Text(
              L.t('طریقہ کار', 'How It Works'),
              style: _ts(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.primaryColor,
                height: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              L.t(
                'سائن اپ سے پہلی کلاس تک — چند منٹ میں。',
                'From Signup to First Class — In Minutes.',
              ),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: isWide ? 34 : 24,
                fontWeight: FontWeight.w900,
                color: theme.textColor,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              L.t(
                'حقیقی تین قدم — نہ سافٹ ویئر کی الجھن، نہ shared لنکس。',
                'Three simple steps — no software confusion, no shared links.',
              ),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: 16,
                color: theme.subtextColor,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 40),
            if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: buildStepCard(steps[0])),
                    const SizedBox(width: 20),
                    Expanded(child: buildStepCard(steps[1])),
                    const SizedBox(width: 20),
                    Expanded(child: buildStepCard(steps[2])),
                  ],
                ),
              )
            else
              Column(
                children: steps
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: buildStepCard(s),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // --- 4. WHY US / CORE FEATURES SECTION ---
  Widget _buildFeaturesSection(ThemePreset theme, bool isWide) {
    final features = [
      {
        'icon': Icons.video_camera_front_rounded,
        'titleUrdu': 'لائیو ماہر کلاسز',
        'titleEn': 'Live Expert Classes',
        'descUrdu': 'اصل freelancers اور ماہرین سے لائیو سیکھیں — کسی بھی ڈیوائس سے شیڈول کردہ بیچ جوائن کریں۔',
        'descEn': 'Learn live from real freelancers and experts — join scheduled batches from any device.',
      },
      {
        'icon': Icons.translate_rounded,
        'titleUrdu': 'اپنی زبان میں سیکھیں',
        'titleEn': 'Learn in Your Language',
        'descUrdu': 'کلاس اور AI مدد اردو اور انگریزی دونوں میں — جو آپ کو آسان لگے۔',
        'descEn': 'Classes and AI assistance in both Urdu and English — whichever suits you best.',
      },
      {
        'icon': Icons.smart_toy_rounded,
        'titleUrdu': 'AI لرننگ اسسٹنٹ',
        'titleEn': 'AI Learning Assistant',
        'descUrdu': 'فوری وضاحت، نوٹس اور practice سوالات — 24/7، اردو یا انگریزی میں۔',
        'descEn': 'Instant explanations, notes, and practice questions — 24/7 in Urdu or English.',
      },
      {
        'icon': Icons.fact_check_rounded,
        'titleUrdu': 'حاضری اور پیش رفت',
        'titleEn': 'Attendance & Progress',
        'descUrdu': 'ہر جوائن خودکار درج ہوتا ہے، تاکہ والدین اور اساتذہ حاضری و پیش رفت دیکھ سکیں۔',
        'descEn': 'Every join is logged automatically so parents and teachers can track progress.',
      },
      {
        'icon': Icons.phonelink_lock_rounded,
        'titleUrdu': 'ایک ڈیوائس سیکیورٹی',
        'titleEn': 'Single Device Security',
        'descUrdu': 'ہر اکاؤنٹ ایک وقت میں ایک ہی ڈیوائس پر — نہ پاس ورڈ شیئرنگ، نہ ڈبل لاگ ان۔',
        'descEn': 'Each account is restricted to one device at a time — no password sharing or double login.',
      },
      {
        'icon': Icons.tune_rounded,
        'titleUrdu': 'لچکدار پلانز',
        'titleEn': 'Flexible Plans',
        'descUrdu': 'مفت ٹرائل، ماہانہ Paid، یا ایڈوانس کورسز کے لیے Premier — جب چاہیں اپ گریڈ کریں۔',
        'descEn': 'Free Trial, Monthly Paid, or Premier for advanced courses — upgrade anytime.',
      },
    ];

    Widget buildFeatureCard(Map<String, dynamic> item) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: Icon(
                item['icon'] as IconData,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              L.t(item['titleUrdu'] as String, item['titleEn'] as String),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              L.t(item['descUrdu'] as String, item['descEn'] as String),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.7,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1150),
        child: Column(
          children: [
            // PROMINENT SECTION TAG (22pt)
            Text(
              L.t('ہم ہی کیوں؟', 'Why Choose Us?'),
              style: _ts(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.primaryColor,
                height: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              L.t(
                'صرف ویڈیو کال نہیں — مکمل سیکھنے کا تجربہ —',
                'Not just video calls — a complete learning experience —',
              ),
              style: _ts(
                fontSize: isWide ? 34 : 24,
                fontWeight: FontWeight.w900,
                color: theme.textColor,
                height: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              L.t(
                'ہر خصوصیت آپ کو اسکل سیکھنے اور آن لائن کمانے کے قریب لے جاتی ہے۔',
                'Every feature brings you closer to learning skills and earning online.',
              ),
              style: _ts(
                fontSize: 16,
                color: theme.subtextColor,
                height: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (isWide)
              Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: buildFeatureCard(features[0])),
                        const SizedBox(width: 20),
                        Expanded(child: buildFeatureCard(features[1])),
                        const SizedBox(width: 20),
                        Expanded(child: buildFeatureCard(features[2])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: buildFeatureCard(features[3])),
                        const SizedBox(width: 20),
                        Expanded(child: buildFeatureCard(features[4])),
                        const SizedBox(width: 20),
                        Expanded(child: buildFeatureCard(features[5])),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: features
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: buildFeatureCard(item),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 64),
            _buildAIMentorBanner(theme, isWide),
          ],
        ),
      ),
    );
  }

  Widget _buildAIMentorBanner(ThemePreset theme, bool isWide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 28 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildAIChatGraphicMockup(isWide),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 6,
                  child: _buildAIMentorTextContent(isWide),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAIMentorTextContent(isWide),
                const SizedBox(height: 20),
                _buildAIChatGraphicMockup(isWide),
              ],
            ),
    );
  }

  Widget _buildAIMentorTextContent(bool isWide) {
    return Column(
      crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          L.t('کبھی اکیلے نہ اٹکیں', 'Never Get Stuck Alone'),
          style: _ts(
            fontSize: isWide ? 18 : 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF34D399),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          L.t('ایک AI مینٹور جو آپ کی زبان بولے۔', 'An AI Mentor That Speaks Your Language —'),
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: _ts(
            fontSize: isWide ? 30 : 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          L.t(
            'کلاس میں کوئی بات رہ گئی یا آدھی رات پریکٹس کر رہے ہیں؟ سادہ اردو یا انگریزی میں پوچھیں اور واضح، مرحلہ وار رہنمائی پائیں۔ تاکہ آپ کہیں رکیں نہیں۔',
            'Missed something in class or practicing at midnight? Ask in simple Urdu or English and get clear step-by-step guidance — so you never get stuck.',
          ),
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: _ts(
            fontSize: isWide ? 14 : 12,
            color: Colors.white.withValues(alpha: 0.95),
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildAIChatGraphicMockup(bool isWide) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              L.t('سر، Fiverr پر پہلا gig کیسے بناؤں؟', 'Sir, how do I make my first Gig on Fiverr?'),
              style: _ts(fontSize: isWide ? 13 : 11, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              L.t(
                'پہلے اپنی skill چنیں، پھر ایک واضح title اور 3 packages بنائیں۔ آئیے آپ کے gig کا title لکھتے ہیں۔۔۔',
                'First select your skill, then create a clear title and 3 packages. Let\'s write your gig title...',
              ),
              style: _ts(fontSize: isWide ? 13 : 11, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              L.t('کلائنٹ کو proposal لکھنے میں مدد کریں؟', 'Can you help write a proposal for the client?'),
              style: _ts(fontSize: isWide ? 13 : 11, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // --- 5. PRICING / PLANS SECTION ---
  Widget _buildPlansSection(ThemePreset theme, bool isWide, bool isLoggedIn) {
    final plans = [
      {
        'titleUrdu': 'اگست ٹرائل',
        'titleEn': 'August Trial',
        'priceUrdu': 'مفت / 7 دن',
        'priceEn': 'Free / 7 Days',
        'subUrdu': 'بغیر ادائیگی اسکلز سیکھنا شروع کریں۔',
        'subEn': 'Start learning skills without any payment.',
        'btnText': 'مفت شروع کریں',
        'isPopular': false,
        'features': [
          L.t('7 دن کی لائیو ٹرائل کلاسز', '7 days live trial classes'),
          L.t('کوئی verification نہیں، فوری آغاز', 'No verification needed, instant start'),
          L.t('AI اسسٹنٹ شامل', 'AI assistant included'),
        ],
      },
      {
        'titleUrdu': 'اگست Paid',
        'titleEn': 'August Paid',
        'priceUrdu': 'داخلہ / مکمل رسائی',
        'priceEn': 'Enrollment / Full Access',
        'subUrdu': 'مکمل کورس تک رسائی — ماہانہ۔',
        'subEn': 'Full course access — monthly.',
        'btnText': 'ابھی داخلہ لیں',
        'isPopular': true,
        'features': [
          L.t('آپ کے کورس کی تمام لائیو کلاسز', 'All live classes for your course'),
          L.t('حاضری اور پیش رفت کی نگرانی', 'Attendance and progress tracking'),
          L.t('فیس ایک بار ٹیچر verify کرے', 'Teacher verifies fee once'),
        ],
      },
      {
        'titleUrdu': 'اگست Premier',
        'titleEn': 'August Premier',
        'priceUrdu': 'ایڈوانس / کورس',
        'priceEn': 'Advance / Course',
        'subUrdu': 'ایڈوانس اور خصوصی کورسز کے لیے۔',
        'subEn': 'For advanced and special courses.',
        'btnText': 'Premier دیکھیں',
        'isPopular': false,
        'features': [
          L.t('Premier ایڈوانس بیچ', 'Premier advance batch'),
          L.t('ترجیحی ٹیچر سپورٹ', 'Priority teacher support'),
          L.t('گہرے AI practice سیشنز', 'In-depth AI practice sessions'),
        ],
      },
    ];

    Widget buildCard(Map<String, dynamic> p) {
      final isPop = p['isPopular'] as bool;
      final feats = p['features'] as List<String>;
      return Container(
        width: isWide ? 340 : double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: isPop ? 2.5 : 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: isPop ? 0.45 : 0.3),
              blurRadius: isPop ? 26 : 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                SizedBox(
                  height: 28,
                  child: isPop
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            L.t('سب سے مقبول', 'MOST POPULAR'),
                            style: _ts(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF059669)),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),
                Text(
                  L.t(p['titleUrdu'] as String, p['titleEn'] as String),
                  textAlign: TextAlign.center,
                  style: _ts(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  L.t(p['priceUrdu'] as String, p['priceEn'] as String),
                  textAlign: TextAlign.center,
                  style: _ts(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6EE7B7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  L.t(p['subUrdu'] as String, p['subEn'] as String),
                  textAlign: TextAlign.center,
                  style: _ts(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.6,
                  ),
                ),
                Divider(
                    height: 28,
                    color: Colors.white.withValues(alpha: 0.3)),
                ...feats.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF6EE7B7),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f,
                              style: _ts(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.95),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (isLoggedIn) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  } else {
                    _navigateToAuth(isSignUp: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPop ? const Color(0xFF0F172A) : Colors.white,
                  foregroundColor: isPop ? Colors.white : const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 6,
                ),
                child: Text(
                  p['btnText'] as String,
                  style: _ts(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isPop ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1150),
        child: Column(
          children: [
            // PROMINENT SECTION TAG (22pt)
            Text(
              L.t('پلانز', 'Plans'),
              style: _ts(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.primaryColor,
                height: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              L.t('مفت شروع کریں۔ ضرورت پر اپ گریڈ —', 'Start Free. Upgrade When Needed —'),
              style: _ts(
                fontSize: isWide ? 34 : 24,
                fontWeight: FontWeight.w900,
                color: theme.textColor,
                height: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              L.t('ادائیگی سے پہلے آزمائیں۔ پھر اپنے مقصد کے مطابق پیج چنیں۔', 'Try before paying. Then choose the package according to your goal.'),
              style: _ts(
                fontSize: 16,
                color: theme.subtextColor,
                height: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: buildCard(plans[0])),
                    const SizedBox(width: 20),
                    Expanded(child: buildCard(plans[1])),
                    const SizedBox(width: 20),
                    Expanded(child: buildCard(plans[2])),
                  ],
                ),
              )
            else
              Column(
                children: plans
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: buildCard(p),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // --- 6. CTA BANNER ---
  Widget _buildCtaBanner(ThemePreset theme, bool isLoggedIn, bool isWide) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20, vertical: isWide ? 42 : 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            // Top Small Tag (Mint Green Pill Container)
            Container(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 22 : 16, vertical: isWide ? 8 : 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.8), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                L.t('آپ کی نئی اسکل منتظر ہے', 'Your New Skill Awaits'),
                textAlign: TextAlign.center,
                style: _ts(
                  fontSize: isWide ? 18 : 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF34D399),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Main Headline (2 lines with clean spacing)
            Column(
              children: [
                Text(
                  L.t('آپ کی نئی اسکل بس', 'Your new skill is just'),
                  textAlign: TextAlign.center,
                  style: _ts(
                    fontSize: isWide ? 38 : 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
                Text(
                  L.t('ایک بٹن کی دوری پر —', 'One button press away —'),
                  textAlign: TextAlign.center,
                  style: _ts(
                    fontSize: isWide ? 40 : 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Subtext (Crisp Pure White with Spaced Line Height)
            Text(
              L.t(
                'دنیا میں کہیں بھی ہوں، سیکھنا آج شروع کریں۔ 7 دن کی مفت ٹرائل لیں۔',
                'Wherever you are in the world, start learning today. Get a 7-day free trial.',
              ),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: isWide ? 17 : 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 30),

            // Buttons Row (Primary & Secondary Outlined)
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (isLoggedIn) {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    } else {
                      _navigateToAuth(isSignUp: true);
                    }
                  },
                  icon: Icon(Icons.flash_on_rounded, size: isWide ? 20 : 18),
                  label: Text(
                    isLoggedIn
                        ? L.t('ڈیش بورڈ پر جائیں', 'Go to Dashboard')
                        : L.t('7 دن کی مفت ٹرائل شروع کریں', 'Start 7-Day Free Trial'),
                    style: _ts(fontSize: isWide ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 22, vertical: isWide ? 16 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 10,
                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.6),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _scrollToSection(_howItWorksKey),
                  icon: Icon(Icons.explore_outlined, size: isWide ? 20 : 18, color: Colors.white),
                  label: Text(
                    L.t('طریقہ کار', 'How It Works'),
                    style: _ts(fontSize: isWide ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 2.0),
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 28 : 20, vertical: isWide ? 16 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 7. MULTI-COLUMN RESPONSIVE FOOTER ---
  Widget _buildFooter(ThemePreset theme, bool isWide) {
    final socials = [
      {
        'name': 'Facebook',
        'url': 'https://facebook.com',
        'color': const Color(0xFF1877F2),
      },
      {
        'name': 'Instagram',
        'url': 'https://instagram.com',
        'color': const Color(0xFFE4405F),
      },
      {
        'name': 'YouTube',
        'url': 'https://youtube.com',
        'color': const Color(0xFFFF0000),
      },
      {
        'name': 'TikTok',
        'url': 'https://tiktok.com',
        'color': const Color(0xFF00F2FE),
      },
      {
        'name': 'WhatsApp',
        'url': 'https://wa.me/',
        'color': const Color(0xFF25D366),
      },
    ];

    final footerBg = theme.isDark
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.5), theme.bgColor)
        : Color.alphaBlend(theme.primaryColor.withValues(alpha: 0.05), theme.cardColor);

    return Container(
      width: double.infinity,
      color: footerBg,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 60 : 24,
        vertical: 50,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Column(
            children: [
              if (isWide)
                // Desktop 3-Column Layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1 (Brand Info)
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBrandLogo(theme: theme),
                          const SizedBox(height: 16),
                          Text(
                            L.t(
                              'دنیا بھر کے سیکھنے والوں کے لیے لائیو آن لائن اسکلز — AI کے ساتھ。',
                              'Live online skills for learners worldwide — powered by AI.',
                            ),
                            style: _ts(
                              fontSize: 15,
                              color: const Color(0xFF94A3B8),
                              height: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),

                    // Column 2 (Navigation Links)
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.t('ہماری ویب سائٹ', 'Navigation'),
                            style: _ts(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildFooterLink(
                            label: L.t('طریقہ کار', 'How It Works'),
                            onTap: () => _scrollToSection(_howItWorksKey),
                          ),
                          _buildFooterLink(
                            label: L.t('ہم ہی کیوں؟', 'Why Us?'),
                            onTap: () => _scrollToSection(_whyUsKey),
                          ),
                          _buildFooterLink(
                            label: L.t('پلانز', 'Plans'),
                            onTap: () => _scrollToSection(_plansKey),
                          ),
                          _buildFooterLink(
                            label: L.t('کن کے لیے', 'For Whom?'),
                            onTap: () => _scrollToSection(_useCaseKey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),

                    // Column 3 (Social Connect with Names - 2 by 2 Layout)
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.t('ہم سے جڑیں', 'Connect With Us'),
                            style: _ts(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: socials.map((s) {
                              return _buildSocialCard(
                                label: s['name'] as String,
                                color: s['color'] as Color,
                                onTap: () => _openSocialUrl(s['url'] as String),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // Mobile View
                Column(
                  children: [
                    _buildBrandLogo(theme: theme),
                    const SizedBox(height: 14),
                    Text(
                      L.t(
                        'دنیا بھر کے سیکھنے والوں کے لیے لائیو آن لائن اسکلز — AI کے ساتھ。',
                        'Live online skills for learners worldwide — powered by AI.',
                      ),
                      textAlign: TextAlign.center,
                      style: _ts(
                        fontSize: 14,
                        color: const Color(0xFF94A3B8),
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildFooterLink(
                          label: L.t('طریقہ کار', 'How It Works'),
                          onTap: () => _scrollToSection(_howItWorksKey),
                        ),
                        _buildFooterLink(
                          label: L.t('ہم ہی کیوں؟', 'Why Us?'),
                          onTap: () => _scrollToSection(_whyUsKey),
                        ),
                        _buildFooterLink(
                          label: L.t('پلانز', 'Plans'),
                          onTap: () => _scrollToSection(_plansKey),
                        ),
                        _buildFooterLink(
                          label: L.t('کن کے لیے', 'For Whom?'),
                          onTap: () => _scrollToSection(_useCaseKey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      L.t('ہم سے جڑیں', 'Connect With Us'),
                      style: _ts(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: socials.map((s) {
                        return _buildSocialCard(
                          label: s['name'] as String,
                          color: s['color'] as Color,
                          onTap: () => _openSocialUrl(s['url'] as String),
                        );
                      }).toList(),
                    ),
                  ],
                ),

              const SizedBox(height: 36),
              const Divider(color: Color(0xFF1E293B)),
              const SizedBox(height: 20),

              // Copyright Notice
              Text(
                L.t('© 2026 ایکس اکیڈمی پورٹل — جملہ حقوق محفوظ ہیں۔', '© 2026 Xacademy Portal — All Rights Reserved.'),
                style: _ts(fontSize: 13, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: _ts(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialCard({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OfficialBrandLogo(brand: label, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: _ts(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- OFFICIAL BRAND LOGO VECTOR PAINTER ---
class OfficialBrandLogo extends StatelessWidget {
  final String brand;
  final double size;

  const OfficialBrandLogo({super.key, required this.brand, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandLogoPainter(brand: brand),
      ),
    );
  }
}

class _BrandLogoPainter extends CustomPainter {
  final String brand;
  _BrandLogoPainter({required this.brand});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final b = brand.toLowerCase();

    if (b.contains('whatsapp')) {
      // 1. WhatsApp Speech Bubble + Phone
      final bgPaint = Paint()..color = const Color(0xFF25D366);
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, bgPaint);

      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.12;

      final path = Path()
        ..addArc(Rect.fromLTWH(w * 0.22, h * 0.22, w * 0.56, h * 0.56), 0.6, 5.0)
        ..lineTo(w * 0.18, h * 0.82)
        ..close();
      canvas.drawPath(path, whitePaint);

      final innerPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(w * 0.5, h * 0.48), w * 0.14, innerPaint);
    } else if (b.contains('instagram')) {
      // 2. Instagram Sunset Gradient Box + Lens
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        Radius.circular(w * 0.28),
      );
      final gradPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF77737)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h));

      canvas.drawRRect(rect, gradPaint);

      final linePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.64, h * 0.64),
          Radius.circular(w * 0.18),
        ),
        linePaint,
      );

      canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.16, linePaint);

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(w * 0.68, h * 0.32), w * 0.05, dotPaint);
    } else if (b.contains('tiktok')) {
      // 3. TikTok Cyan / Magenta Musical Note
      final cyanPaint = Paint()..color = const Color(0xFF00F2FE);
      final magPaint = Paint()..color = const Color(0xFFFE2C55);
      final whitePaint = Paint()..color = Colors.white;

      canvas.drawCircle(Offset(w * 0.38, h * 0.68), w * 0.22, magPaint);
      canvas.drawCircle(Offset(w * 0.34, h * 0.64), w * 0.22, cyanPaint);
      canvas.drawCircle(Offset(w * 0.36, h * 0.66), w * 0.18, whitePaint);

      final stemRect = Rect.fromLTWH(w * 0.48, h * 0.16, w * 0.14, h * 0.54);
      canvas.drawRect(stemRect, whitePaint);

      final flagPath = Path()
        ..moveTo(w * 0.62, h * 0.16)
        ..cubicTo(w * 0.78, h * 0.22, w * 0.88, h * 0.35, w * 0.88, h * 0.48)
        ..lineTo(w * 0.74, h * 0.48)
        ..cubicTo(w * 0.74, h * 0.38, w * 0.68, h * 0.28, w * 0.62, h * 0.26)
        ..close();
      canvas.drawPath(flagPath, cyanPaint);
    } else if (b.contains('youtube')) {
      // 4. YouTube Red Play Box
      final bgPaint = Paint()..color = const Color(0xFFFF0000);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.12, w, h * 0.76),
        Radius.circular(w * 0.22),
      );
      canvas.drawRRect(rect, bgPaint);

      final triPath = Path()
        ..moveTo(w * 0.4, h * 0.34)
        ..lineTo(w * 0.68, h * 0.5)
        ..lineTo(w * 0.4, h * 0.66)
        ..close();
      final playPaint = Paint()..color = Colors.white;
      canvas.drawPath(triPath, playPaint);
    } else {
      // 5. Facebook Royal Blue Circle with 'f'
      final bgPaint = Paint()..color = const Color(0xFF1877F2);
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.5, bgPaint);

      TextPainter(
        text: TextSpan(
          text: 'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: w * 0.75,
            fontWeight: FontWeight.w900,
            fontFamily: 'sans-serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(w * 0.35, h * 0.08));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 3D INTERACTIVE PERSPECTIVE HERO SLIDER (UNIFIED 4 SLIDES) ---
class Hero3DSlider extends StatefulWidget {
  final ThemePreset theme;
  final bool isLoggedIn;
  final VoidCallback onNavigateToAuth;
  final VoidCallback onNavigateToSignUp;
  final VoidCallback onScrollToHowItWorks;

  const Hero3DSlider({
    super.key,
    required this.theme,
    required this.isLoggedIn,
    required this.onNavigateToAuth,
    required this.onNavigateToSignUp,
    required this.onScrollToHowItWorks,
  });

  @override
  State<Hero3DSlider> createState() => _Hero3DSliderState();
}

class _Hero3DSliderState extends State<Hero3DSlider> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.96);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % 4;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  TextStyle _ts({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? Colors.white,
      height: height ?? (AppLang.ur ? 1.8 : 1.5),
      fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: isWide ? 570 : 510,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: 4,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 0.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page ?? 0.0) - index;
                  } else {
                    value = (_currentPage - index).toDouble();
                  }

                  final s = (1.0 - (value.abs() * 0.08)).clamp(0.75, 1.0);
                  final matrix = Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(value * -0.3)
                    ..setEntry(0, 0, s)
                    ..setEntry(1, 1, s);

                  return Transform(
                    transform: matrix,
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: (1.0 - (value.abs() * 0.35)).clamp(0.45, 1.0),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: _buildSlideContent(index),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // Dots Indicator & Arrow Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: widget.theme.textColor),
              onPressed: () {
                final prevPage = (_currentPage - 1 + 4) % 4;
                _pageController.animateToPage(prevPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
              },
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 28 : 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: isActive ? widget.theme.primaryColor : widget.theme.subtextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: widget.theme.textColor),
              onPressed: () {
                final nextPage = (_currentPage + 1) % 4;
                _pageController.animateToPage(nextPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlideContent(int index) {
    final isWide = MediaQuery.of(context).size.width > 768;

    if (index == 0) {
      // Slide 0: Main Hero Intro & Tagline Slide (Scaled Up for Full Screen Impact)
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 22 : 16, vertical: isWide ? 8 : 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                L.t('آپ کی نئی اسکل منتظر ہے 🚀', 'Your New Skill Awaits 🚀'),
                style: _ts(
                  fontSize: isWide ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              L.t('آپ کی نئی اسکل بس ایک کلک کی دوری پر ہے۔', 'Your New Skill Is Just A Click Away.'),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: isWide ? 38 : 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              L.t('دنیا میں کہیں بھی ہوں، سیکھنا آج شروع کریں۔ 7 دن کی مفت ٹرائل لیں۔', 'Wherever You Are In The World, Start Learning Today. Take A 7-Day Free Trial.'),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: isWide ? 17 : 14,
                color: Colors.white.withValues(alpha: 0.95),
                height: 1.7,
              ),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.isLoggedIn) {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    } else {
                      widget.onNavigateToSignUp();
                    }
                  },
                  icon: Icon(Icons.flash_on_rounded, size: isWide ? 22 : 18),
                  label: Text(
                    widget.isLoggedIn ? L.t('ڈیش بورڈ پر جائیں', 'Go To Dashboard') : L.t('مفت ٹرائل شروع کریں', 'Start Free Trial'),
                    style: _ts(fontSize: isWide ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 34 : 24, vertical: isWide ? 16 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 10,
                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.6),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onScrollToHowItWorks,
                  icon: Icon(Icons.explore_outlined, size: isWide ? 22 : 18, color: Colors.white),
                  label: Text(
                    L.t('طریقہ کار', 'How It Works'),
                    style: _ts(fontSize: isWide ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 2.0),
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 30 : 22, vertical: isWide ? 16 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (index == 1) {
      // Slide 1: AI ACADEMY ONLINE LEARNING (Scaled Up Tech Cards)
      return Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isWide ? 14 : 10),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF2563EB)],
                    ),
                  ),
                  child: Icon(Icons.psychology_rounded, color: Colors.white, size: isWide ? 34 : 28),
                ),
                const SizedBox(width: 14),
                Text(
                  'AI ACADEMY',
                  style: _ts(fontSize: isWide ? 30 : 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              L.t('EMPOWER YOURSELF IN AI', 'EMPOWER YOURSELF IN AI'),
              textAlign: TextAlign.center,
              style: _ts(fontSize: isWide ? 24 : 18, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              L.t('کورسز، پروجیکٹس اور کمیونٹی', 'Courses, Projects & Community'),
              textAlign: TextAlign.center,
              style: _ts(fontSize: isWide ? 16 : 13, color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 20,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                _buildMiniTechCard(
                  icon: Icons.code_rounded,
                  title: 'Python for AI',
                  desc: 'مشین لرننگ',
                  isWide: isWide,
                ),
                _buildMiniTechCard(
                  icon: Icons.auto_awesome_rounded,
                  title: 'ML Foundations',
                  desc: 'ایڈوانس لرننگ',
                  isWide: isWide,
                ),
              ],
            ),
          ],
        ),
      );
    } else if (index == 2) {
      // Slide 2: Live Instructor Session (Sir Sikandarhayat Baba - Scaled Up)
      return Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  L.t('شام 7:00 · 60 منٹ', '7:00 PM · 60 mins'),
                  style: _ts(fontSize: isWide ? 14 : 12, color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF34D399), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        L.t('ابھی لائیو', 'LIVE NOW'),
                        style: _ts(fontSize: isWide ? 13 : 11, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              L.t('مصنوعی ذہانت (AI) اور جدید ٹیکنالوجی اسکلز', 'AI & Future Tech Skills'),
              textAlign: TextAlign.center,
              style: _ts(fontSize: isWide ? 26 : 18, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              L.t('فری لانسنگ — شروع سے کمائی تک', 'Freelancing — From Start to Earnings'),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: isWide ? 22 : 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF34D399),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: isWide ? 56 : 44,
                  height: isWide ? 56 : 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text('SK', style: _ts(fontSize: isWide ? 20 : 16, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L.t('سر سکندر حیات بابا', 'Sir Sikandarhayat Baba'),
                      style: _ts(fontSize: isWide ? 20 : 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      L.t('بیچ: اگست · لائیو سیشن', 'Batch: August · Live Session'),
                      style: _ts(fontSize: isWide ? 14 : 12, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: widget.onNavigateToAuth,
              icon: Icon(Icons.video_call_rounded, size: isWide ? 24 : 20),
              label: Text(
                L.t('کلاس جوائن کریں', 'Join Class'),
                style: _ts(fontSize: isWide ? 17 : 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: isWide ? 50 : 40, vertical: isWide ? 15 : 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 8,
              ),
            ),
          ],
        ),
      );
    } else {
      // Slide 3: Learn & Earn From Anywhere (Matching 2nd & 3rd Images - Center Aligned)
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Badge Tag (Image 3)
            Container(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 22 : 16, vertical: isWide ? 8 : 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.7), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                L.t('لائیو آن لائن اسکلز اکیڈمی AI کے ساتھ', 'Live Online Skills Academy with AI'),
                textAlign: TextAlign.center,
                style: _ts(
                  fontSize: isWide ? 16 : 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF34D399),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Main Headline (Image 3)
            Column(
              children: [
                Text(
                  L.t('سیکھیں، کمائیں —', 'Learn, Earn —'),
                  textAlign: TextAlign.center,
                  style: _ts(
                    fontSize: isWide ? 38 : 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                Text(
                  L.t('کہیں سے بھی —', 'From Anywhere —'),
                  textAlign: TextAlign.center,
                  style: _ts(
                    fontSize: isWide ? 40 : 30,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF34D399),
                    height: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Body Subtext (Image 2 & 3)
            Text(
              L.t(
                'ماہرین سے فری لانسنگ اور آن-ڈیمانڈ ڈیجیٹل اسکلز لائیو سیکھیں — دور ہوں، مصروف ہوں یا بیرونِ ملک — اور AI کی مدد سے آن لائن کمائی کی طرف بڑھیں۔',
                'Learn freelancing and on-demand digital skills live from experts — whether distant, busy, or overseas — and move towards online earnings with the help of AI.',
              ),
              textAlign: TextAlign.center,
              style: _ts(
                fontSize: isWide ? 16 : 13,
                color: Colors.white.withValues(alpha: 0.95),
                height: 1.7,
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons Row (Image 2)
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.isLoggedIn) {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    } else {
                      widget.onNavigateToSignUp();
                    }
                  },
                  icon: Icon(Icons.flash_on_rounded, size: isWide ? 22 : 18),
                  label: Text(
                    L.t('7 دن کی مفت ٹرائل شروع کریں', 'Start 7-Day Free Trial'),
                    style: _ts(fontSize: isWide ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 22, vertical: isWide ? 16 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 10,
                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.6),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onScrollToHowItWorks,
                  icon: Icon(Icons.explore_outlined, size: isWide ? 22 : 18, color: Colors.white),
                  label: Text(
                    L.t('طریقہ دیکھیں', 'See How It Works'),
                    style: _ts(fontSize: isWide ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 2.0),
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 28 : 20, vertical: isWide ? 16 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Social Proof Bottom Bar (Image 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatarStack(isWide),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    L.t('دنیا بھر میں سیکھنے والے — کراچی سے دبئی اور ٹورنٹو تک۔', 'Learners worldwide — from Karachi to Dubai and Toronto.'),
                    textAlign: TextAlign.center,
                    style: _ts(
                      fontSize: isWide ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAvatarStack(bool isWide) {
    final letters = ['A', 'S', 'M', '+'];
    final colors = [const Color(0xFF10B981), const Color(0xFF2563EB), const Color(0xFF059669), const Color(0xFF34D399)];
    final size = isWide ? 28.0 : 24.0;

    return SizedBox(
      height: size,
      width: (letters.length * (size - 10)) + 10,
      child: Stack(
        children: List.generate(letters.length, (i) {
          return Positioned(
            left: i * (size - 10),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: colors[i].withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                letters[i],
                style: TextStyle(
                  fontSize: isWide ? 12 : 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }



  Widget _buildMiniTechCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool isWide,
  }) {
    return Container(
      width: isWide ? 220 : 180,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 18 : 14, vertical: isWide ? 12 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: isWide ? 26 : 22),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: _ts(fontSize: isWide ? 14 : 12, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: _ts(fontSize: isWide ? 12 : 10, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.95)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- MOVING 3D AI MEMOJI / EMOJI ANIMATED WIDGET ---
class Floating3DAIEmojiWidget extends StatefulWidget {
  final String imagePath;
  final IconData fallbackIcon;
  final String label;
  final double size;
  final Duration duration;
  final double maxTranslationX;
  final double maxTranslationY;
  final Color accentColor;

  const Floating3DAIEmojiWidget({
    super.key,
    required this.imagePath,
    required this.fallbackIcon,
    required this.label,
    required this.size,
    this.duration = const Duration(seconds: 3),
    this.maxTranslationX = 60.0,
    this.maxTranslationY = 30.0,
    this.accentColor = const Color(0xFF00D2FF),
  });

  @override
  State<Floating3DAIEmojiWidget> createState() => _Floating3DAIEmojiWidgetState();
}

class _Floating3DAIEmojiWidgetState extends State<Floating3DAIEmojiWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Corner-to-corner orbital float path & dynamic 3D rotation
        final dx = (0.5 - _animation.value) * (widget.maxTranslationX * 2);
        final dy = (0.5 - _animation.value) * (widget.maxTranslationY * 2);
        final scale = 0.88 + (_animation.value * 0.22);
        final rot = (0.5 - _animation.value) * 0.55;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              widget.accentColor.withValues(alpha: 0.25),
              const Color(0xFF0F172A).withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: widget.accentColor.withValues(alpha: 0.8),
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.45),
              blurRadius: 25,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            widget.imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: widget.accentColor.withValues(alpha: 0.15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.fallbackIcon, color: widget.accentColor, size: widget.size * 0.45),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}


