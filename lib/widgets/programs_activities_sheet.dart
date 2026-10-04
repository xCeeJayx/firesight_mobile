import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProgramsActivitiesSheet extends StatefulWidget {
  const ProgramsActivitiesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProgramsActivitiesSheet(),
    );
  }

  @override
  State<ProgramsActivitiesSheet> createState() =>
      _ProgramsActivitiesSheetState();
}

class _ProgramsActivitiesSheetState extends State<ProgramsActivitiesSheet> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Fire Safety',
    'Outreach',
    'Safety Info',
    'Official Page',
  ];

  Future<void> _openUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $urlString'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/bfp_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Programs & Activities',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'BFP Lingayen Fire Prevention & Community Highlights',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      splashRadius: 20,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Filter Chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                      selectedColor: const Color(0xFFEA580C),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFEA580C)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

              // Content List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    // Section 1: Featured Campaign (Oplan Ligtas na Pamayanan)
                    if (_selectedCategory == 'All' ||
                        _selectedCategory == 'Fire Safety') ...[
                      _buildFeaturedCampaignCard(),
                      const SizedBox(height: 20),
                    ],

                    // Section 2: Fire Safety & Preparedness
                    if (_selectedCategory == 'All' ||
                        _selectedCategory == 'Fire Safety') ...[
                      _buildSectionHeader(
                        icon: Icons.shield_rounded,
                        title: 'Fire Safety & Preparedness',
                        subtitle:
                            'Evacuation drills, training, and barangay assemblies',
                        badgeText: '6 Posts',
                        badgeColor: const Color(0xFFEA580C),
                      ),
                      const SizedBox(height: 10),
                      ..._buildFireSafetyPosts(),
                      const SizedBox(height: 20),
                    ],

                    // Section 3: Community Outreach & Environmental Activities
                    if (_selectedCategory == 'All' ||
                        _selectedCategory == 'Outreach') ...[
                      _buildSectionHeader(
                        icon: Icons.volunteer_activism_rounded,
                        title: 'Community Outreach & Environment',
                        subtitle:
                            'Coastal cleanup drives and summer first aid roving',
                        badgeText: '3 Posts',
                        badgeColor: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 10),
                      ..._buildOutreachPosts(),
                      const SizedBox(height: 20),
                    ],

                    // Section 4: Safety Information
                    if (_selectedCategory == 'All' ||
                        _selectedCategory == 'Safety Info') ...[
                      _buildSectionHeader(
                        icon: Icons.menu_book_rounded,
                        title: 'Safety Information & Advisories',
                        subtitle:
                            'Official safety tips, wiring guides, and 911 hotlines',
                        badgeText: '6 Posts',
                        badgeColor: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 10),
                      ..._buildSafetyInfoPosts(),
                      const SizedBox(height: 20),
                    ],

                    // Section 5: Official FB Page Banner
                    if (_selectedCategory == 'All' ||
                        _selectedCategory == 'Official Page') ...[
                      _buildOfficialPageBanner(),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: badgeColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCampaignCard() {
    const url = 'https://share.google/4uINKK4HxK6QWXRST';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEA580C).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openUrl(url),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'SPECIAL CAMPAIGN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.open_in_new_rounded,
                        color: Color(0xFFEA580C),
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'OPLAN LIGTAS NA PAMAYANAN CAMPAIGN NG BFP, EPEKTIBO LABAN SA SUNOG',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF9A3412),
                    letterSpacing: 0.2,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mas pinaigting ng Bureau of Fire Protection (BFP) Lingayen ang kanilang Oplan Ligtas na Pamayanan—isang programa na may layuning turuan at paalalahanan ang publiko gamit ang roving fire truck at public address.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF431407),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Read Full Article',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'share.google',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9A3412),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFireSafetyPosts() {
    final posts = [
      {
        'title': 'Community Fire Auxiliary Group (CFAG) Activity',
        'subtitle': '28 September 2026 | Obligasyon sa Bayan, Ligtas na Pamayanan',
        'desc': 'BFP-Lingayen facilitated the Community Fire Auxiliary Group (CFAG) training under the “Obligasyon sa Bayan, Ligtas na Pamayanan” program.',
        'url': 'https://www.facebook.com/share/p/1e39cUa14o/',
      },
      {
        'title': 'Fire Safety Lecture, Fire Drill & Earthquake Drill',
        'subtitle': 'Baǹaan Museum, Lingayen, Pangasinan',
        'desc': 'BFP-Lingayen Fire Station conducted a comprehensive Fire Safety Lecture, Fire Drill, and Earthquake Drill at Baǹaan Museum.',
        'url': 'https://www.facebook.com/share/p/1LuNmEuU5s/',
      },
      {
        'title': 'Fire Extinguisher Orientation and Demonstration',
        'subtitle': '29 April 2026 | Hands-on Training',
        'desc': 'Continuous efforts to promote fire safety awareness and community preparedness through fire extinguisher training and live demonstrations.',
        'url': 'https://www.facebook.com/share/p/1CbNfzLJf8/',
      },
      {
        'title': 'Fire Safety Lecture, Drill and Inspection',
        'subtitle': '27 March 2026 | Safety Readiness',
        'desc': 'In line with efforts to promote safety awareness, BFP-Lingayen conducted fire safety lectures, emergency evacuation drills, and proactive inspections.',
        'url': 'https://www.facebook.com/share/p/1NCqxiYP2c/',
      },
      {
        'title': '1st Semester Barangay Assembly — Brgy. Dulag',
        'subtitle': '14 March 2026 | Barangay Dulag, Lingayen',
        'desc': 'BFP-Lingayen participated in the 1st Semester Barangay Assembly at Barangay Dulag, presenting fire safety guidelines to residents.',
        'url': 'https://www.facebook.com/share/p/1DUmtkUTUD/',
      },
      {
        'title': '1st Semester Barangay Assembly — Brgy. Maniboc',
        'subtitle': '14 March 2026 | Barangay Maniboc, Lingayen',
        'desc': 'BFP-Lingayen joined the Barangay Assembly at Barangay Maniboc, sharing crucial fire prevention measures and community defense tips.',
        'url': 'https://www.facebook.com/share/p/1JorLkkc6g/',
      },
    ];

    return posts
        .map(
          (p) => _buildPostCard(
            category: 'Fire Safety',
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFEA580C),
            title: p['title']!,
            subtitle: p['subtitle'],
            description: p['desc']!,
            url: p['url']!,
          ),
        )
        .toList();
  }

  List<Widget> _buildOutreachPosts() {
    final posts = [
      {
        'title': 'SM Cares Coastal Clean-Up',
        'subtitle': '07 June 2026 | Binmaley Baywalk, Pangasinan',
        'desc': 'BFP-Lingayen actively participated in the SM Cares Coastal Clean-Up held at Binmaley Baywalk in support of environmental conservation.',
        'url': 'https://www.facebook.com/share/p/1BwEF68aQu/',
      },
      {
        'title': 'Oplan SUMVAC 2026 — First Aid Service Team (F.A.S.T.)',
        'subtitle': '01 May 2026 | Roving and Inspection',
        'desc': 'BFP-Lingayen remains steadfast in its commitment to public safety through the First Aid Service Team roving and inspection during vacation season.',
        'url': 'https://www.facebook.com/share/p/14rnijxwT22/',
      },
      {
        'title': 'Coastal Clean-Up Drive "Bumbasurero"',
        'subtitle': '20 February 2026 | with PSU Binmaley Interns',
        'desc': 'BFP-Lingayen personnel together with Criminology Interns of PSU Binmaley proudly led and executed the "Bumbasurero" coastal clean-up.',
        'url': 'https://www.facebook.com/share/p/1FEghNGYqY/',
      },
    ];

    return posts
        .map(
          (p) => _buildPostCard(
            category: 'Outreach',
            icon: Icons.eco_rounded,
            iconColor: const Color(0xFF059669),
            title: p['title']!,
            subtitle: p['subtitle'],
            description: p['desc']!,
            url: p['url']!,
          ),
        )
        .toList();
  }

  List<Widget> _buildSafetyInfoPosts() {
    final posts = [
      {
        'title': 'Safe Wiring, Safe Home! ⚡🔥',
        'subtitle': 'Electrical Fire Prevention Advisory',
        'desc': 'Prevent electrical fires by using quality wiring materials, avoiding overloaded outlets, replacing damaged wires, and keeping connections safe.',
        'url': 'https://www.facebook.com/share/p/1CSz19ZTRW/',
      },
      {
        'title': 'Bawal ang Pagsunog ng Damo! 🔥',
        'subtitle': 'Wildfire & Open Burning Warning',
        'desc': 'Ang simpleng pagsunog ng damo ay maaaring magdulot ng mabilis na pagkalat ng apoy at malaking sunog. Panatilihing malinis ang paligid sa ligtas na paraan.',
        'url': 'https://www.facebook.com/share/p/1A4vMxi8jk/',
      },
      {
        'title': 'Iwas Sunog, Ligtas ang Pamilya! 🏠❤️',
        'subtitle': 'Home Fire Safety Advisory',
        'desc': 'Maging alerto at responsable sa paggamit ng kuryente, pagluluto, LPG, at iba pang maaaring pagmulan ng sunog. Ang pag-iingat ngayon ay proteksyon bukas.',
        'url': 'https://www.facebook.com/share/p/19rzQz64JZ/',
      },
      {
        'title': '\'Wag Magsunog ng Basura! 🚫🔥',
        'subtitle': 'Waste Burning & Fire Hazard Advisory',
        'desc': 'Munting apoy, maaaring maging malaking sunog. Iwas sunog, ligtas ang lahat! Panatilihing malinis ang kapaligiran.',
        'url': 'https://www.facebook.com/share/p/1DQuHmQEEc/',
      },
      {
        'title': 'Iwas Sunog, Siguraduhin ang Tuyong Bubong! 🌧️🏠',
        'subtitle': 'Rainy Season Electrical Safety',
        'desc': 'Suriin at ayusin ang mga sirang yero upang maiwasan ang pagtagas ng tubig na maaaring makaabot sa mga kable at saksakan ng kuryente.',
        'url': 'https://www.facebook.com/share/p/1DwsE3ujGz/',
      },
      {
        'title': 'Kalmado. Tumawag. Lumikas. Ligtas. 🧯',
        'subtitle': 'Emergency 911 & Evacuation Steps',
        'desc': 'Sa oras ng sunog o emergency, 911 agad! Ibigay ang tamang lokasyon at impormasyon. Lumikas sa ligtas na lugar—huwag gumamit ng elevator!',
        'url': 'https://www.facebook.com/share/p/1CDb74Bt15/',
      },
    ];

    return posts
        .map(
          (p) => _buildPostCard(
            category: 'Safety Info',
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF2563EB),
            title: p['title']!,
            subtitle: p['subtitle'],
            description: p['desc']!,
            url: p['url']!,
          ),
        )
        .toList();
  }

  Widget _buildPostCard({
    required String category,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required String description,
    required String url,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openUrl(url),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1877F2)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.facebook,
                                  size: 11,
                                  color: Color(0xFF1877F2),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Facebook',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1877F2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialPageBanner() {
    const url = 'https://www.facebook.com/share/1EqwPmgULq/';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openUrl(url),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1877F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.facebook,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'BFP REGION 1 LINGAYEN PANGASINAN',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Official Facebook Page • Your Safety, Our Priority',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.phone_in_talk_rounded,
                        color: Color(0xFFF97316),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Emergency Hotline: 0917-186-1611',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Visit Official Facebook Page',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
