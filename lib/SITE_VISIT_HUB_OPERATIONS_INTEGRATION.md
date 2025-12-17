// lib/SITE_VISIT_HUB_OPERATIONS_INTEGRATION.md

# Site Visit & Hub Operations Integration Guide

**Date:** December 11, 2025  
**Status:** Complete Implementation  
**Version:** 1.0.0

---

## OVERVIEW

This document describes the complete integration of hub operations, site registry matching, and site visit tracking into the PACT Mobile Flutter application. All TypeScript logic from the specification has been faithfully ported to Flutter/Dart while maintaining idiomatic patterns.

---

## TABLE OF CONTENTS

1. [Models & Data Structures](#models--data-structures)
2. [Core Services](#core-services)
3. [Matching Algorithm](#matching-algorithm)
4. [User Flows](#user-flows)
5. [Database Integration](#database-integration)
6. [Cost Tracking](#cost-tracking)
7. [API Reference](#api-reference)

---

## MODELS & DATA STRUCTURES

### 1. Hub Operations Models (`lib/models/hub_operations_models.dart`)

**New models added:**

```dart
// GPS Coordinates with accuracy tracking
GPSCoordinates {
  latitude: double
  longitude: double
  accuracyMeters?: double
}

// Registry matching metadata
MatchQuery {
  siteCode: string
  siteName: string
  state: string
  locality: string
}

MatchInfo {
  type: 'exact_code' | 'name_location' | 'partial' | 'fuzzy' | 'not_found'
  confidence: double (0-1)
  confidenceLevel: 'high' | 'medium' | 'low' | 'none'
  ruleApplied: string
  candidatesCount: int
  autoAccepted: bool
  requiresReview: bool
}

MatchAudit {
  matchedAt: string (ISO8601)
  matchedBy: string
  sourceWorkflow: 'mmp_upload' | 'dispatch' | 'manual' | 'system'
  overrideReason?: string
}

RegistryLinkage {
  registrySiteId?: string
  registrySiteCode?: string
  gps?: GPSCoordinates
  stateId?: string
  stateName?: string
  localityId?: string
  localityName?: string
  query: MatchQuery
  match: MatchInfo
  audit: MatchAudit
  unmatched?: UnmatchedInfo
  alternativeCandidates?: List<AlternativeCandidate>
}

SiteRegistry {
  id: string
  siteCode: string
  siteName: string
  stateId: string
  stateName: string
  localityId: string
  localityName: string
  hubId?: string
  hubName?: string
  gpsLatitude?: double
  gpsLongitude?: double
  activityType?: string
  status: 'registered' | 'active' | 'inactive' | 'archived'
  mmpCount: int
  createdAt: string
  createdBy: string
}

ManagedHub {
  id: string
  name: string
  description?: string
  states: List<string>
  coordinates?: Map<string, dynamic>
}

ProjectScope {
  id: string
  projectId: string
  hubId?: string
  stateIds?: List<string>
  localityIds?: List<string>
}

SiteMatchResult {
  siteEntryId: string
  siteName: string
  siteCode?: string
  state: string
  locality: string
  matchedRegistry?: SiteRegistry
  matchType: 'exact_code' | 'name_location' | 'partial' | 'fuzzy' | 'not_found'
  matchConfidence: double
  matchConfidenceLevel: 'high' | 'medium' | 'low' | 'none'
  autoAccepted: bool
  requiresReview: bool
  gpsCoordinates?: GPSCoordinates
  allCandidates: List<AlternativeCandidate>
  registryLinkage: RegistryLinkage
}

RegistryValidationResult {
  matches: List<SiteMatchResult>
  registeredCount: int
  unregisteredCount: int
  reviewRequiredCount: int
  autoAcceptedCount: int
  warnings: List<string>
}
```

### 2. Extended SiteVisit Model (`lib/models/site_visit.dart`)

**New fields added to `SiteVisit` class:**

```dart
// Tracking columns (from mmp_site_entries)
verifiedBy?: string
verifiedAt?: DateTime
dispatchedBy?: string
dispatchedAt?: DateTime
acceptedBy?: string
acceptedAt?: DateTime
updatedAt?: DateTime

// Cost columns (new explicit columns, not in additional_data)
enumeratorFee?: double
transportFee?: double
totalCost?: double
costAcknowledged: bool = false
costAcknowledgedAt?: DateTime
costAcknowledgedBy?: string

// Registry linkage
registrySiteId?: string
registryLinkage?: Map<string, dynamic>
additionalData?: Map<string, dynamic>
```

**Helper methods added:**

```dart
// Calculate total cost from fees
double? get calculatedTotalCost

// Check if cost has been fully acknowledged
bool get isCostFullyAcknowledged

// Check if registry linkage exists
bool get hasValidRegistryLinkage

// Status checks
bool get isCompleted
bool get isPending
bool get isAccepted
bool get isVerified
```

---

## CORE SERVICES

### 1. Sites Registry Matcher (`lib/utils/sites_registry_matcher.dart`)

**Primary class:** `SitesRegistryMatcher`

**Key methods:**

```dart
// Fetch all sites from registry
Future<List<SiteRegistry>> fetchAllRegistrySites()

// Core matching algorithm (faithful TypeScript port)
SiteMatchResult matchSiteToRegistry(
  Map<string, dynamic> siteEntry,
  List<SiteRegistry> registrySites, {
  String? userId,
  String sourceWorkflow = 'mmp_upload',
})

// Batch validation for multiple sites
Future<RegistryValidationResult> validateSitesAgainstRegistry(
  List<Map<string, dynamic>> siteEntries, {
  String? userId,
  String sourceWorkflow = 'mmp_upload',
})

// GPS saving to registry
Future<GPSSaveResult> saveGPSToRegistry(
  String registrySiteId,
  double latitude,
  double longitude, {
  double? accuracy,
  String? userId,
  String sourceType = 'site_visit',
  bool overwriteExisting = false,
})

// GPS saving from site entry
Future<GPSSaveResult> saveGPSToRegistryFromSiteEntry(
  String mmpSiteEntryId,
  double latitude,
  double longitude, { ... }
)

// Site code generation & parsing
String generateSiteCode(
  String stateCode,
  String localityName,
  String siteName,
  int sequenceNumber, {
  String activityType = 'TPM',
})

SiteCodeComponents? parseSiteCode(String siteCode)
```

### 2. Extended Site Visit Service (`lib/services/site_visit_service.dart`)

**New methods added:**

```dart
// Verification workflow
Future<void> verifySiteEntry(String siteEntryId, String userId)
  // Updates: status = 'Verified', verified_by, verified_at, updated_at

// Dispatch workflow
Future<void> dispatchSiteEntry(
  String siteEntryId,
  String userId, {
  String? toDataCollectorId,
})
  // Updates: status = 'Dispatched', dispatched_by, dispatched_at, updated_at

// Flagging workflow
Future<void> flagSiteEntry(
  String siteEntryId,
  String flagReason, {
  String? flaggedBy,
})
  // Stores in additional_data: isFlagged, flagReason, flaggedBy, flaggedAt

// Cost acknowledgment
Future<void> acknowledgeCost(String siteEntryId, String userId)
  // Updates: cost_acknowledged, cost_acknowledged_at, cost_acknowledged_by

// Hub & Registry queries
Future<List<Map<string, dynamic>>> getAllHubs()
Future<List<Map<string, dynamic>>> getAllSitesRegistry()
Future<Map<string, dynamic>?> getRegistryLinkage(String siteEntryId)
Future<Map<string, dynamic>?> getSiteCostSummary(String siteEntryId)

// Filtering
Future<List<SiteVisit>> getSitesByStatus(String status)
Future<List<SiteVisit>> getSitesByHub(String hubId)
Future<List<Map<string, dynamic>>> getPendingCostAcknowledgments()
```

---

## MATCHING ALGORITHM

### Confidence Scoring (Faithful TypeScript Port)

```
Input: siteEntry(siteCode, siteName, state, locality)
Output: SiteMatchResult with confidence 0-1

SCORING RULES (in priority order):
1. exact_code: siteCode matches registry site_code exactly
   Confidence: 1.0 (100%)
   Auto-accept: YES (if >= 0.90)
   
2. name_location: siteName + state + locality all match
   Confidence: 0.85 (85%)
   Auto-accept: NO (requires review)
   
3. partial_state: siteName + state match (no locality)
   Confidence: 0.70 (70%)
   Auto-accept: NO (requires review)
   
4. fuzzy_name: siteName only matches
   Confidence: 0.50 (50%)
   Auto-accept: NO (requires review)
   
5. not_found: no matches
   Confidence: 0.0 (0%)
   Auto-accept: NO (unmatched)

NORMALIZATION:
- Convert all strings to lowercase
- Remove all non-alphanumeric characters
- Collapse whitespace
- Compare normalized values

AUTO-ACCEPT RULES:
- ONLY exact_code matches auto-accept (confidence >= 0.90)
- All other matches require manual review
- GPS coordinates populated automatically ONLY on auto-accept
```

### Implementation

```dart
// From lib/utils/sites_registry_matcher.dart

SiteMatchResult matchSiteToRegistry(
  Map<String, dynamic> siteEntry,
  List<SiteRegistry> registrySites, {
  String? userId,
  String sourceWorkflow = 'mmp_upload',
}) {
  // 1. Extract fields (handle both camelCase and snake_case)
  final siteCode = siteEntry['siteCode'] ?? siteEntry['site_code'] ?? '';
  final siteName = siteEntry['siteName'] ?? siteEntry['site_name'] ?? '';
  final state = siteEntry['state'] ?? '';
  final locality = siteEntry['locality'] ?? '';

  // 2. Normalize strings
  final normalizedCode = _normalizeString(siteCode);
  final normalizedName = _normalizeString(siteName);
  final normalizedState = _normalizeString(state);
  final normalizedLocality = _normalizeString(locality);

  // 3. Score all candidates against input
  final candidates = <MapEntry<SiteRegistry, double>>[];
  
  for (final registrySite in registrySites) {
    double confidence = 0.0;
    
    // Rule 1: Exact code (1.0)
    if (normalizedCode == _normalizeString(registrySite.siteCode)) {
      confidence = MATCH_EXACT_CODE; // 1.0
    }
    // Rule 2: Name+State+Locality (0.85)
    else if (
      normalizedName == _normalizeString(registrySite.siteName) &&
      normalizedState == _normalizeString(registrySite.stateName) &&
      normalizedLocality == _normalizeString(registrySite.localityName)
    ) {
      confidence = MATCH_NAME_LOCATION; // 0.85
    }
    // Rule 3: Name+State (0.70)
    else if (
      normalizedName == _normalizeString(registrySite.siteName) &&
      normalizedState == _normalizeString(registrySite.stateName)
    ) {
      confidence = MATCH_PARTIAL_STATE; // 0.70
    }
    // Rule 4: Name only (0.50)
    else if (normalizedName == _normalizeString(registrySite.siteName)) {
      confidence = MATCH_FUZZY_NAME; // 0.50
    }
    
    if (confidence > 0.0) {
      candidates.add(MapEntry(registrySite, confidence));
    }
  }

  // 4. Sort by confidence (highest first)
  candidates.sort((a, b) => b.value.compareTo(a.value));

  // 5. Get best match
  final bestMatch = candidates.isNotEmpty ? candidates.first : null;
  final matchConfidence = bestMatch?.value ?? 0.0;
  final autoAccepted = matchConfidence >= CONFIDENCE_AUTO_ACCEPT; // >= 0.90
  final requiresReview = matchConfidence > 0 && matchConfidence < CONFIDENCE_AUTO_ACCEPT;

  // 6. Populate GPS ONLY if auto-accepted
  final gps = autoAccepted && bestMatch != null && 
              bestMatch.key.gpsLatitude != null &&
              bestMatch.key.gpsLongitude != null
    ? GPSCoordinates(
        latitude: bestMatch.key.gpsLatitude!,
        longitude: bestMatch.key.gpsLongitude!,
      )
    : null;

  // 7. Build audit trail
  final audit = MatchAudit(
    matchedAt: DateTime.now().toIso8601String(),
    matchedBy: userId ?? 'system',
    sourceWorkflow: sourceWorkflow,
  );

  // 8. Create registry linkage object
  final registryLinkage = RegistryLinkage(
    registrySiteId: bestMatch?.key.id,
    registrySiteCode: bestMatch?.key.siteCode,
    gps: gps,
    stateId: bestMatch?.key.stateId,
    stateName: bestMatch?.key.stateName,
    localityId: bestMatch?.key.localityId,
    localityName: bestMatch?.key.localityName,
    query: MatchQuery(
      siteCode: siteCode,
      siteName: siteName,
      state: state,
      locality: locality,
    ),
    match: MatchInfo(
      type: _getMatchType(matchConfidence),
      confidence: matchConfidence,
      confidenceLevel: _getConfidenceLevel(matchConfidence),
      ruleApplied: _getRuleApplied(_getMatchType(matchConfidence)),
      candidatesCount: candidates.length,
      autoAccepted: autoAccepted,
      requiresReview: requiresReview,
    ),
    audit: audit,
    alternativeCandidates: candidates.map((e) => AlternativeCandidate(...)).toList(),
  );

  // 9. Return complete result
  return SiteMatchResult(
    siteEntryId: siteEntry['id']?.toString() ?? 'unknown',
    siteName: siteName,
    siteCode: siteCode,
    state: state,
    locality: locality,
    matchedRegistry: bestMatch?.key,
    matchType: _getMatchType(matchConfidence),
    matchConfidence: matchConfidence,
    matchConfidenceLevel: _getConfidenceLevel(matchConfidence),
    autoAccepted: autoAccepted,
    requiresReview: requiresReview,
    gpsCoordinates: gps,
    allCandidates: alternativeCandidates,
    registryLinkage: registryLinkage,
  );
}
```

---

## USER FLOWS

### Flow 1: Upload & Match MMP File

```
User selects CSV file
  ↓
Frontend calls uploadMMPFile() or manual entry
  ↓
ParseCSV with header normalization
  ├─ Headers: hubOffice, siteName, state, locality, cpName, etc.
  ├─ Convert booleans: "Yes"/"No" → true/false
  └─ Store unmapped fields in additionalData
  ↓
ForEach site entry:
  ├─ Call matchSiteToRegistry(entry, allRegistrySites, userId, 'mmp_upload')
  ├─ Receive SiteMatchResult with:
  │   ├─ matchType: 'exact_code'|'name_location'|'partial'|'fuzzy'|'not_found'
  │   ├─ matchConfidence: 0-1 numeric
  │   ├─ autoAccepted: bool (true only if exact_code)
  │   ├─ gpsCoordinates: (if autoAccepted, from registry)
  │   └─ registryLinkage: full audit trail + alternatives
  │
  └─ Store in mmp_site_entries:
      ├─ registry_site_id (FK to sites_registry)
      ├─ status = 'Pending'
      ├─ Set explicit cost columns:
      │   ├─ enumerator_fee
      │   ├─ transport_fee
      │   └─ calculated totalCost
      └─ additional_data JSON:
          ├─ registry_linkage (full object)
          ├─ registry_gps (legacy format)
          └─ other mapped fields

✓ Result: Site entries ready for dispatch/verification
  - Auto-accepted entries have GPS from registry
  - Entries requiring review flagged for manual check
```

### Flow 2: Dispatch to Data Collector (Coordinator)

```
Coordinator views MMP file in Hub Operations
  ↓
Opens SiteDetailDialog for specific site
  ├─ Display all site info normalized from:
  │   ├─ Direct columns: site_name, site_code, state, locality
  │   ├─ Cost columns: enumerator_fee, transport_fee
  │   ├─ Tracking columns: verified_by/at, dispatched_by/at, accepted_by/at
  │   └─ Registry linkage from additional_data
  │
  └─ If requires_review: show alternative candidates
      ├─ User can manually select different registry match
      └─ Override system selection
  ↓
Coordinator selects data collector and clicks "Dispatch"
  ↓
SiteVisitService.dispatchSiteEntry():
  ├─ Update mmp_site_entries:
  │   ├─ status = 'Dispatched'
  │   ├─ dispatched_by = currentUserId
  │   ├─ dispatched_at = now()
  │   ├─ (optional) accepted_by = selectedDataCollectorId
  │   └─ updated_at = now() [auto via trigger]
  └─ Return updated entry
  ↓
Frontend confirms and updates UI
✓ Data collector now sees in "Assigned Sites"
```

### Flow 3: Data Collector Accepts & Visits Site

```
Data collector sees "Assigned Sites" list
  ↓
Opens SiteDetailDialog
  ├─ Display:
  │   ├─ Site code, name, location
  │   ├─ Monitoring requirements
  │   ├─ Fee breakdown: enumerator_fee + transport_fee
  │   ├─ Registry GPS (if auto-accepted)
  │   └─ Verification status (if already verified)
  │
  └─ If status != 'Accepted': show "Accept Site" button
  ↓
Data collector clicks "Accept Site"
  ↓
SiteVisitService.acceptVisit():
  ├─ Update mmp_site_entries:
  │   ├─ status = 'Accepted'
  │   ├─ accepted_by = currentUserId
  │   ├─ accepted_at = now()
  │   ├─ updated_at = now()
  │   └─ [Auto-capture location + store in location_logs]
  └─ Return updated entry
  ↓
Frontend moves to "My Accepted Sites"
  ├─ Ready for data collection
  └─ Can now navigate to site with registry GPS coordinates
  ↓
Data collector conducts monitoring at site
  ├─ Collects visit data
  ├─ (Optional) Captures GPS if not in registry
  │   └─ Call saveGPSToRegistry() to update sites_registry
  └─ Completes visit form
  ↓
Marks visit complete
✓ Site now in "Completed Sites" → ready for verification
```

### Flow 4: Supervisor Verification

```
Supervisor reviews "Completed Sites"
  ↓
Opens SiteDetailDialog with "Verify" action
  ├─ Display:
  │   ├─ All site information
  │   ├─ Collected visit data
  │   ├─ Data quality indicators
  │   ├─ Accepted by (data collector name)
  │   └─ Registry match details
  │
  └─ Show "Verify" or "Flag for Review" buttons
  ↓
Supervisor clicks "Verify"
  ↓
SiteVisitService.verifySiteEntry():
  ├─ Update mmp_site_entries:
  │   ├─ status = 'Verified'
  │   ├─ verified_by = supervisorUserId
  │   ├─ verified_at = now()
  │   └─ updated_at = now()
  └─ Return updated entry
  ↓
Frontend confirms verification
✓ Site moves to "Verified Sites"
  ├─ Ready for dispatch to finance for cost acknowledgment
  └─ Data collector can now claim in Wallet
  ↓
[OR if issues]
Supervisor clicks "Flag for Review"
  ↓
SiteVisitService.flagSiteEntry():
  ├─ Store in additional_data:
  │   ├─ isFlagged = true
  │   ├─ flagReason = supervisor input
  │   ├─ flaggedBy = supervisorUserId
  │   └─ flaggedAt = now()
  └─ Status unchanged (remains 'Completed')
  ↓
Frontend marks with warning badge
✓ Escalated for manual review
```

### Flow 5: Finance Cost Acknowledgment

```
Finance/Admin user views pending cost acknowledgments
  ├─ Query: getSitesByStatus('Verified') or getPendingCostAcknowledgments()
  ├─ Display cost breakdown:
  │   ├─ Site info
  │   ├─ enumerator_fee
  │   ├─ transport_fee
  │   ├─ Total cost
  │   └─ Status (Pending/Acknowledged)
  │
  └─ Show "Acknowledge Cost" button (if cost_acknowledged = false)
  ↓
Finance user reviews and clicks "Acknowledge Cost"
  ↓
SiteVisitService.acknowledgeCost():
  ├─ Update mmp_site_entries:
  │   ├─ cost_acknowledged = true
  │   ├─ cost_acknowledged_at = now()
  │   ├─ cost_acknowledged_by = financeUserId (FK to profiles.id)
  │   └─ updated_at = now()
  └─ Return updated entry
  ↓
Frontend confirms acknowledgment
✓ Cost now shows as "Acknowledged"
  ├─ Data collector notified
  └─ Can now claim payment in Wallet
  ↓
[Wallet Integration]
  ├─ Data collector views earnings
  ├─ Sees site visit transactions:
  │   ├─ siteVisitId, siteCode, siteName
  │   ├─ enumeratorFee, transportFee
  │   ├─ totalEarned = enumeratorFee + transportFee
  │   ├─ status = 'acknowledged'
  │   └─ acknowledgedAt, acknowledgedBy
  │
  ├─ Can request payment/withdrawal
  └─ Payment flows through normal Wallet withdrawal process
```

---

## DATABASE INTEGRATION

### Schema Updates (Migrations)

**Table: `mmp_site_entries`** (Primary tracking table)

| Column | Type | Purpose |
|--------|------|---------|
| `id` | uuid | Primary key |
| `mmp_file_id` | uuid | FK to mmp_files |
| `registry_site_id` | text | **NEW**: FK to sites_registry |
| `site_code` | varchar | Unique identifier |
| `site_name` | varchar | Display name |
| `state` | varchar | State/region |
| `locality` | varchar | District/locality |
| `hub_office` | varchar | Hub assignment |
| `verified_by` | text | **NEW**: Who verified |
| `verified_at` | timestamptz | **NEW**: When verified |
| `dispatched_by` | text | **NEW**: Who dispatched |
| `dispatched_at` | timestamptz | **NEW**: When dispatched |
| `accepted_by` | text | **NEW**: Data collector who accepted |
| `accepted_at` | timestamptz | **NEW**: When data collector accepted |
| `enumerator_fee` | numeric | **NEW**: Explicit fee column |
| `transport_fee` | numeric | **NEW**: Explicit fee column |
| `cost_acknowledged` | boolean | **NEW**: Cost reviewed flag |
| `cost_acknowledged_at` | timestamptz | **NEW**: When acknowledged |
| `cost_acknowledged_by` | uuid | **NEW**: FK to profiles, who acknowledged |
| `additional_data` | jsonb | Stores registry_linkage, custom fields |
| `updated_at` | timestamptz | **NEW**: Auto-maintained via trigger |
| `status` | varchar | Pending/Accepted/Verified/Dispatched/etc |
| `created_at` | timestamptz | Record creation |

**Table: `sites_registry`** (Master site registry)

| Column | Type | Purpose |
|--------|------|---------|
| `id` | text | Primary key |
| `site_code` | varchar(50) | Unique site identifier |
| `site_name` | varchar(200) | Display name |
| `state_id` | varchar(20) | State identifier |
| `state_name` | varchar(100) | State name |
| `locality_id` | varchar(50) | Locality identifier |
| `locality_name` | varchar(100) | District/locality name |
| `hub_id` | text | FK to hubs |
| `hub_name` | varchar(100) | Hub name (denormalized) |
| `gps_latitude` | decimal(10, 6) | Latitude coordinate |
| `gps_longitude` | decimal(10, 6) | Longitude coordinate |
| `gps_captured_by` | text | Who captured GPS |
| `gps_captured_at` | timestamptz | When GPS captured |
| `activity_type` | varchar(20) | TPM/PDM/CFM/FCS |
| `status` | varchar(20) | registered/active/inactive/archived |
| `mmp_count` | int | Count of MMP entries referencing this |
| `last_mmp_date` | date | Date of most recent MMP entry |
| `created_at` | timestamptz | Record creation |
| `created_by` | text | Who created |
| `updated_at` | timestamptz | Last update |

**Table: `hubs`** (Hub/office management)

| Column | Type | Purpose |
|--------|------|---------|
| `id` | text | Primary key |
| `name` | varchar(100) | Hub name (e.g., "Kassala Hub") |
| `description` | text | Hub description |
| `states` | text[] | Array of state IDs served |
| `coordinates` | jsonb | {latitude, longitude} |
| `created_at` | timestamptz | Record creation |
| `created_by` | text | Who created |
| `updated_at` | timestamptz | Last update |

---

## COST TRACKING

### Fields & Columns

```
Explicit cost columns (direct DB columns, not JSONB):
├─ enumerator_fee: double
├─ transport_fee: double
├─ cost_acknowledged: boolean (default: false)
├─ cost_acknowledged_at: timestamptz
└─ cost_acknowledged_by: uuid (FK to profiles.id)

Calculated field:
└─ totalCost = enumerator_fee + transport_fee
```

### Acknowledgment Workflow

```
1. Site visit completed
   ├─ Data has: enumerator_fee, transport_fee
   └─ cost_acknowledged = false (default)

2. Finance reviews cost
   ├─ Can query: SELECT * WHERE cost_acknowledged = false AND enumerator_fee IS NOT NULL
   └─ See total: (enumerator_fee + transport_fee) per site

3. Finance acknowledges cost
   ├─ Call: acknowledgeCost(siteEntryId, financeUserId)
   ├─ Updates:
   │   ├─ cost_acknowledged = true
   │   ├─ cost_acknowledged_at = NOW()
   │   ├─ cost_acknowledged_by = financeUserId
   │   └─ updated_at = NOW() (via trigger)
   └─ Returns updated entry

4. Wallet Integration
   ├─ Data collector views "Site Visit Earnings"
   ├─ Transaction type: 'SITE_VISIT_EARNING'
   ├─ Amount = enumerator_fee + transport_fee
   ├─ Status = 'acknowledged' (if cost_acknowledged = true)
   └─ Can request withdrawal

5. Withdrawal
   ├─ Data collector requests payment
   ├─ Amount = totalCost from site entry
   ├─ Status changes in Wallet system
   ├─ Finance approves
   └─ Amount transferred to wallet balance
```

### SiteVisit Helper Methods

```dart
// Calculate total cost from fees
double? get calculatedTotalCost {
  if (enumeratorFee == null && transportFee == null) return null;
  return (enumeratorFee ?? 0) + (transportFee ?? 0);
}

// Check if cost has been fully acknowledged (all 3 fields set)
bool get isCostFullyAcknowledged =>
    costAcknowledged && 
    costAcknowledgedAt != null && 
    costAcknowledgedBy != null;

// Get cost summary for display
Future<Map<string, dynamic>?> getSiteCostSummary(String siteEntryId) async {
  // Returns: {
  //   enumerator_fee, transport_fee, total_cost,
  //   cost_acknowledged, cost_acknowledged_at, cost_acknowledged_by
  // }
}
```

---

## API REFERENCE

### SitesRegistryMatcher

```dart
class SitesRegistryMatcher {
  // Registry operations
  Future<List<SiteRegistry>> fetchAllRegistrySites()
  
  // Core matching
  SiteMatchResult matchSiteToRegistry(
    Map<String, dynamic> siteEntry,
    List<SiteRegistry> registrySites,
    {String? userId, String sourceWorkflow = 'mmp_upload'}
  )
  
  // Batch validation
  Future<RegistryValidationResult> validateSitesAgainstRegistry(
    List<Map<String, dynamic>> siteEntries,
    {String? userId, String sourceWorkflow = 'mmp_upload'}
  )
  
  // GPS management
  Future<GPSSaveResult> saveGPSToRegistry(
    String registrySiteId,
    double latitude,
    double longitude,
    {double? accuracy, String? userId, String sourceType = 'site_visit', bool overwriteExisting = false}
  )
  
  Future<GPSSaveResult> saveGPSToRegistryFromSiteEntry(
    String mmpSiteEntryId,
    double latitude,
    double longitude,
    {double? accuracy, String? userId, String sourceType = 'site_visit', bool overwriteExisting = false}
  )
  
  // Code generation
  String generateSiteCode(
    String stateCode,
    String localityName,
    String siteName,
    int sequenceNumber,
    {String activityType = 'TPM'}
  )
  
  SiteCodeComponents? parseSiteCode(String siteCode)
}
```

### SiteVisitService (Extended)

```dart
// Tracking workflows
Future<void> verifySiteEntry(String siteEntryId, String userId)
Future<void> dispatchSiteEntry(String siteEntryId, String userId, {String? toDataCollectorId})
Future<void> flagSiteEntry(String siteEntryId, String flagReason, {String? flaggedBy})
Future<void> acknowledgeCost(String siteEntryId, String userId)

// Hub & Registry queries
Future<List<Map<String, dynamic>>> getAllHubs()
Future<List<Map<String, dynamic>>> getAllSitesRegistry()
Future<Map<String, dynamic>?> getRegistryLinkage(String siteEntryId)
Future<Map<String, dynamic>?> getSiteCostSummary(String siteEntryId)

// Filtering
Future<List<SiteVisit>> getSitesByStatus(String status)
Future<List<SiteVisit>> getSitesByHub(String hubId)
Future<List<Map<String, dynamic>>> getPendingCostAcknowledgments()
```

---

## INTEGRATION CHECKLIST

- [x] Hub operations models created
- [x] Site registry matching algorithm ported
- [x] SiteVisit model extended with tracking columns
- [x] Cost columns added to SiteVisit
- [x] SiteVisitService extended with new methods
- [x] GPS saving functionality implemented
- [x] Site code generation implemented
- [x] Documentation complete

---

## NEXT STEPS

1. **Run code generation:**
   ```bash
   flutter pub run build_runner build
   ```

2. **Database migrations:**
   - Execute all 5 migrations (see DATABASE MIGRATIONS & SCHEMA in spec)
   - Verify tables created with proper indexes and RLS policies

3. **Integration testing:**
   - Test matching algorithm with sample data
   - Verify GPS saving functionality
   - Test cost acknowledgment workflow
   - Test all status transitions

4. **UI Integration:**
   - Connect HubOperations page with new services
   - Display registry matching results
   - Show cost breakdown and acknowledgment UI
   - Display tracking columns in SiteDetailDialog

---

## NOTES

- All TypeScript logic has been faithfully ported to Dart
- No "smart assign" patterns used (as requested)
- Strong typing maintained throughout
- Error handling follows existing patterns
- All comments preserved and enhanced
- Backward compatibility maintained with existing site_visit_service methods

**Last Updated:** December 11, 2025
