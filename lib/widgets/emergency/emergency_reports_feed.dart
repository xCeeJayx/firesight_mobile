import 'package:flutter/material.dart';
import '../../models/emergency_report_model.dart';
import '../../services/emergency_service.dart';
import 'emergency_details_bottom_sheet.dart';

class EmergencyReportsFeed extends StatefulWidget {
  final String? title;
  final int maxItems;
  final bool showHeader;
  final EdgeInsetsGeometry padding;
  final bool isExpanded;
  final ScrollPhysics? physics;

  const EmergencyReportsFeed({
    super.key,
    this.title = 'Live Emergency Reports Stream',
    this.maxItems = 15,
    this.showHeader = true,
    this.padding = EdgeInsets.zero,
    this.isExpanded = false,
    this.physics,
  });

  @override
  State<EmergencyReportsFeed> createState() => _EmergencyReportsFeedState();
}

class _EmergencyReportsFeedState extends State<EmergencyReportsFeed>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _selectedFilter = 'All'; // 'All', 'Unverified', 'Verified', 'Responding', 'Resolved'

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isExpanded) {
      return Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) _buildSectionHeader(),
            const SizedBox(height: 12),
            _buildFilterChips(),
            const SizedBox(height: 12),
            Expanded(child: _buildFeedList(scrollable: true)),
          ],
        ),
      );
    }

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) _buildSectionHeader(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 12),
          _buildFeedList(scrollable: false),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return ValueListenableBuilder<List<EmergencyReportModel>>(
      valueListenable: EmergencyService().reportsNotifier,
      builder: (context, reports, child) {
        final unverifiedCount = reports.where((r) => r.status.toLowerCase() == 'unverified').length;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  // Pulsing Live Dot
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFDC2626).withValues(alpha: _pulseAnimation.value),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: _pulseAnimation.value * 0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title ?? 'Live Emergency Reports Stream',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unverifiedCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unverifiedCount Urgent',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                InkWell(
                  onTap: () => EmergencyService().fetchReports(),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Unverified', 'Verified', 'Responding', 'Resolved'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              selectedColor: const Color(0xFFDC2626).withValues(alpha: 0.15),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
              ),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF64748B),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeedList({bool scrollable = false}) {
    return ValueListenableBuilder<bool>(
      valueListenable: EmergencyService().isLoadingNotifier,
      builder: (context, isLoading, child) {
        return ValueListenableBuilder<List<EmergencyReportModel>>(
          valueListenable: EmergencyService().reportsNotifier,
          builder: (context, reports, child) {
            if (isLoading && reports.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Color(0xFFDC2626)),
              );
            }

            // Apply filter
            final filteredReports = _selectedFilter == 'All'
                ? reports
                : reports.where((r) => r.status.toLowerCase() == _selectedFilter.toLowerCase()).toList();

            if (filteredReports.isEmpty) {
              final emptyWidget = Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 32,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No Active Emergency Reports',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedFilter == 'All'
                          ? 'Real-time incident reports will appear here automatically.'
                          : 'No reports found matching status "$_selectedFilter".',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );

              if (scrollable) {
                return SingleChildScrollView(
                  physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: emptyWidget,
                );
              }
              return emptyWidget;
            }

            final itemsToShow = filteredReports.take(widget.maxItems).toList();

            return ListView.separated(
              shrinkWrap: !scrollable,
              physics: scrollable ? (widget.physics ?? const AlwaysScrollableScrollPhysics()) : const NeverScrollableScrollPhysics(),
              padding: scrollable ? const EdgeInsets.only(bottom: 24) : EdgeInsets.zero,
              itemCount: itemsToShow.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final report = itemsToShow[index];
                return _buildEmergencyReportCard(report);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmergencyReportCard(EmergencyReportModel report) {
    final hasPhoto = report.photoUrl != null && report.photoUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () => EmergencyDetailsBottomSheet.show(context, report),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: report.status.toLowerCase() == 'unverified'
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE2E8F0),
              width: report.status.toLowerCase() == 'unverified' ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail or Incident Icon
              if (hasPhoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: const Color(0xFF0F172A),
                    child: Image.network(
                      report.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: report.incidentColor.withValues(alpha: 0.1),
                        child: Icon(report.incidentIcon, color: report.incidentColor, size: 24),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: report.incidentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    report.incidentIcon,
                    color: report.incidentColor,
                    size: 24,
                  ),
                ),

              const SizedBox(width: 12),

              // Content Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Incident Type & Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: report.incidentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              report.incidentType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: report.incidentColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: report.statusBgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: report.statusTextColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            report.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: report.statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Barangay & Address
                    Text(
                      'Brgy. ${report.barangay}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (report.address != null && report.address!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        report.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Timestamp & Reporter
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          report.formattedTimeAgo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (report.reporterName != null && report.reporterName!.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              report.reporterName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
