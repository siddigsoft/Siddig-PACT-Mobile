// lib/screens/equipment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/equipment.dart';
import '../services/equipment_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  late EquipmentService _equipmentService;
  List<Equipment> _equipment = [];
  String _selectedFilter = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    final prefs = await SharedPreferences.getInstance();
    _equipmentService = EquipmentService(prefs);
    _loadEquipment();
  }

  void _loadEquipment() {
    setState(() {
      _isLoading = true;
    });

    final equipment = _equipmentService.filterEquipment(
      status: _selectedFilter == 'All' ? null : _selectedFilter,
      searchQuery: _searchQuery,
    );

    setState(() {
      _equipment = equipment;
      _isLoading = false;
    });
  }

  Future<void> _showAddEquipmentDialog() async {
    final nameController = TextEditingController();
    final maintenanceDateController = TextEditingController();
    String selectedStatus = 'OK';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.addNewEquipment,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.equipmentName,
                  hintText: AppLocalizations.of(context)!.enterEquipmentName,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: ['OK', 'Needs Service']
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  selectedStatus = value!;
                },
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.status),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maintenanceDateController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.nextMaintenanceDate,
                  hintText: AppLocalizations.of(context)!.yyyyMmDd,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  maintenanceDateController.text.isNotEmpty) {
                final newEquipment = Equipment(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  status: selectedStatus,
                  isCheckedIn: true,
                  nextMaintenance: maintenanceDateController.text,
                );

                await _equipmentService.addEquipment(newEquipment);
                _loadEquipment();
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white, // Ensure text is visible
            ),
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
  }

  Future<void> _showInspectionDialog(Equipment? equipment) async {
    if (equipment == null) return;

    final conditionController = TextEditingController();
    final concernsController = TextEditingController();
    final recommendationsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.inspectionForm,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                equipment.name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: conditionController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.condition,
                  hintText: AppLocalizations.of(context)!.enterCurrentCondition,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: concernsController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.concerns,
                  hintText: AppLocalizations.of(context)!.enterAnyConcerns,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: recommendationsController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.recommendations,
                  hintText: AppLocalizations.of(context)!.enterRecommendations,
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (conditionController.text.isNotEmpty) {
                final inspection = Inspection(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  date: DateTime.now().toIso8601String(),
                  condition: conditionController.text,
                  concerns: concernsController.text,
                  recommendations: recommendationsController.text,
                );

                await _equipmentService.addInspection(equipment.id, inspection);
                _loadEquipment();
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: Text(AppLocalizations.of(context)!.submit),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFilterChips(),
                            const SizedBox(height: 16),
                            if (_equipment.isNotEmpty)
                              ...List.generate(
                                _equipment.length,
                                (index) => _buildEquipmentItem(
                                  name: _equipment[index].name,
                                  status: _equipment[index].status,
                                  isCheckedIn: _equipment[index].isCheckedIn,
                                  nextMaintenance:
                                      _equipment[index].nextMaintenance,
                                  statusColor: _equipment[index].status == 'OK'
                                      ? AppColors.accentGreen
                                      : AppColors.accentRed,
                                  onCheckedChanged: (value) async {
                                    final updatedEquipment = Equipment(
                                      id: _equipment[index].id,
                                      name: _equipment[index].name,
                                      status: _equipment[index].status,
                                      isCheckedIn: value,
                                      nextMaintenance:
                                          _equipment[index].nextMaintenance,
                                      inspections:
                                          _equipment[index].inspections,
                                    );
                                    await _equipmentService.updateEquipment(
                                      updatedEquipment,
                                    );
                                    _loadEquipment();
                                  },
                                  onTap: () =>
                                      _showInspectionDialog(_equipment[index]),
                                ),
                              ),
                            if (_equipment.isEmpty)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: AppColors.textLight,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      AppLocalizations.of(context)!.noEquipmentFound,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(context)!.tapPlusButtonToAddEquipment,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showAddEquipmentDialog();
        },
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundGray,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                // Navigation logic would go here
              },
              icon: const Icon(Icons.arrow_back),
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            AppLocalizations.of(context)!.equipment,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              // Show bottom sheet with filter options
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.filterEquipment,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFilterChips(),
                    ],
                  ),
                ),
              );
            },
            icon: Icon(
              Icons.filter_list,
              color: AppColors.primaryOrange,
              size: 28,
            ),
          ),
          IconButton(
            onPressed: () {
              // Show search dialog
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    AppLocalizations.of(context)!.searchEquipment,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: TextField(
                    onChanged: (value) {
                      _searchQuery = value;
                      _loadEquipment();
                    },
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.enterEquipmentNameSearch,
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.close),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.search, color: AppColors.primaryOrange, size: 28),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(AppLocalizations.of(context)!.all, true),
          _buildFilterChip(AppLocalizations.of(context)!.available, false),
          _buildFilterChip(AppLocalizations.of(context)!.inUse, false),
          _buildFilterChip(AppLocalizations.of(context)!.needsMaintenance, false),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        selectedColor: AppColors.primaryOrange.withOpacity(0.1),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.primaryOrange : AppColors.borderColor,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primaryOrange : AppColors.textLight,
          ),
        ),
        onSelected: (value) {
          setState(() {
            _selectedFilter = label;
          });
          _loadEquipment();
        },
      ),
    );
  }

  Widget _buildEquipmentItem({
    required String name,
    required String status,
    required bool isCheckedIn,
    required String nextMaintenance,
    required Color statusColor,
    required Function(bool) onCheckedChanged,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppLocalizations.of(context)!.next}: $nextMaintenance',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: isCheckedIn,
              onChanged: onCheckedChanged,
              activeColor: AppColors.primaryOrange,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
    child:
    Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: status == 'OK'
                            ? AppColors.accentGreen.withOpacity(0.1)
                            : AppColors.accentRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.build_outlined,
                        color: status == 'OK'
                            ? AppColors.accentGreen
                            : AppColors.accentRed,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == 'OK'
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  color: statusColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    status,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: statusColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Wrapped in a container with constraints to prevent overflow
                    Container(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              isCheckedIn ? AppLocalizations.of(context)!.checkedIn : AppLocalizations.of(context)!.checkedOut,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isCheckedIn,
                            onChanged: (value) {
                              // Update check-in status
                            },
                            activeThumbColor: AppColors.primaryOrange,
                            activeTrackColor: AppColors.primaryOrange
                                .withOpacity(0.3),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.textLight.withOpacity(
                              0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // Prevent unnecessary stretching
                  children: [
                    Text(
                      '${AppLocalizations.of(context)!.nextMaintenance}: ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLight,
                      ),
                    ),
                    Flexible(
                      // Allow text to wrap if needed
                      child: Text(
                        nextMaintenance,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms);
  }
}
