# Code Implementation Details

## Summary of Changes

This document provides detailed code snippets for all changes made to ensure data collectors can receive and claim site visits.

---

## 1. Database Migrations Applied

### ✅ Migration 1: Tracking Columns (20250120)
```sql
-- Adds verified_by, verified_at, dispatched_by, dispatched_at, updated_at
-- Location: supabase/migrations/20250120_add_tracking_columns_to_mmp_site_entries.sql
-- Status: CREATED ✅
```

### ✅ Migration 2: Accepted/Claimed Columns (20250125)
```sql
-- Adds accepted_by, accepted_at, claimed_by, claimed_at
-- Location: supabase/migrations/20250125_add_accepted_columns_to_mmp_site_entries.sql
-- Status: CREATED ✅
```

### ✅ Migration 3: Fee Columns (20251121)
```sql
-- Adds enumerator_fee, transport_fee, cost
-- Location: supabase/migrations/20251121_add_mmp_site_entries_cost_columns.sql
-- Status: CREATED ✅
```

### ✅ Migration 4: Classification System (20251123)
```sql
-- Creates user_classifications and classification_fee_structures tables
-- Location: supabase/migrations/20251123_user_classification_system.sql
-- Status: CREATED ✅
```

### ✅ Migration 5: Atomic RPC (20251128)
```sql
-- Creates claim_site_visit RPC function
-- Location: supabase/migrations/20251128_fix_claim_enumerator_fee.sql
-- Status: CREATED ✅

-- Function signature:
CREATE FUNCTION claim_site_visit(
  p_site_id UUID,
  p_user_id UUID,
  p_enumerator_fee NUMERIC DEFAULT NULL,
  p_total_cost NUMERIC DEFAULT NULL,
  p_classification_level TEXT DEFAULT NULL,
  p_role_scope TEXT DEFAULT NULL,
  p_fee_source TEXT DEFAULT 'default'
) RETURNS JSONB
```

---

## 2. Backend Services

### ✅ Auto Release Service (NEW)
**File:** `lib/services/auto_release_service.dart`

**Status:** CREATED ✅

**Key Methods:**
```dart
class AutoReleaseService {
  // Main entry point
  Future<int> checkAndReleaseSites() async {
    // Query assigned sites past deadline
    // Auto-release those not confirmed
    // Send notifications
  }

  // Internal helper
  Future<void> _releaseSite(SiteEntryData site) async {
    // Update site status back to Dispatched
    // Clear assigned fields
    // Notify former assignee
  }
}
```

### ✅ Notification Service (UPDATED)
**File:** `lib/services/notification_trigger_service.dart`

**Status:** ENHANCED ✅

**Added Method:**
```dart
/// NEW: Send notification when site is assigned to collector
Future<void> siteAssigned(
  String userId,
  String siteName,
  String siteId, {
  double? enumeratorFee,
  double? transportFee,
  String? assignedBy,
}) async {
  // Creates notification in notifications table
  // Includes fee breakdown in message
  // Links to site details
}
```

### ✅ Site Visit Service (UPDATED)
**File:** `lib/services/site_visit_service.dart`

**Status:** ENHANCED ✅

**Updated Method:**
```dart
/// UPDATED: Dispatch now sends notifications
Future<void> dispatchSiteEntry(
  String siteEntryId,
  String userId, {
  String? toDataCollectorId,
  String? siteName,
  double? enumeratorFee,
  double? transportFee,
}) async {
  // 1. Update site to Dispatched status
  // 2. NEW: Send notification to assigned collector
  // 3. NEW: Include fee information
  
  // If assigned to individual:
  if (toDataCollectorId != null) {
    await NotificationTriggerService().siteAssigned(...);
  }
}
```

---

## 3. Frontend Components

### ✅ Claim Site Button (UPDATED)
**File:** `lib/widgets/claim_site_button.dart`

**Status:** FIXED ✅

**Before (OLD - BROKEN):**
```dart
Future<void> _claimSiteOnline() async {
  // ❌ Direct DB update
  // ❌ No race condition prevention
  // ❌ No fee calculation
  
  await supabase
      .from('mmp_site_entries')
      .update({
        'claimed_by': userId,
        'claimed_at': DateTime.now().toIso8601String(),
        'status': 'claimed',
      })
      .eq('id', widget.siteEntryId);
}
```

**After (NEW - FIXED):**
```dart
Future<void> _claimSiteOnline() async {
  // ✅ Atomic RPC call
  // ✅ Race condition prevention via FOR UPDATE SKIP LOCKED
  // ✅ Fee calculation from classification
  
  final response = await supabase.rpc(
    'claim_site_visit',
    params: {
      'p_site_id': widget.siteEntryId,
      'p_user_id': userId,
      // Fee calculated automatically from user's classification
    },
  );

  if (response['success'] != true) {
    throw Exception(response['message']);
  }

  // Access calculated fees from response:
  final enumeratorFee = response['enumerator_fee'];
  final transportFee = response['transport_fee'];
  final totalPayout = response['total_payout'];
}
```

---

## 4. Data Flow - Before vs After

### BEFORE (Broken)
```
Collector sees site ➜ Clicks claim
  ➜ Direct DB update
  ➜ ❌ Race condition possible
  ➜ ❌ No fee calculation
  ➜ ❌ Notification not sent
  ➜ Status changed to "claimed"
  ➜ Collector doesn't see fee breakdown
```

### AFTER (Fixed)
```
Hub coordinator creates MMP
  ➜ Verified and cost set
  ➜ Dispatch to "Dispatched" status
  ➜ ✅ Notification sent to collector
     (includes fee breakdown)

Collector sees notification
  ➜ Can see site in available list
  ➜ Sees fee breakdown in UI
  ➜ Clicks claim button

System executes claim_site_visit RPC:
  ✅ Locks site row (FOR UPDATE SKIP LOCKED)
  ✅ Verifies status = "Dispatched"
  ✅ Looks up collector's classification
  ✅ Calculates enumerator_fee from fee structure
  ✅ Updates site with fees and status = "Accepted"
  ✅ Creates notification confirming claim
  ✅ Returns complete fee breakdown

Collector receives confirmation
  ✅ Sees exact payout they'll receive
  ✅ Ready to start site visit
```

---

## 5. Integration Points

### Where to Call Auto-Release Service
**In:** `lib/services/app_config_service.dart` or `main.dart`

```dart
void main() async {
  // ... other initialization ...
  
  // Register auto-release background task
  await Workmanager().initialize(callbackDispatcher);
  
  await Workmanager().registerPeriodicTask(
    'auto_release_sites',
    'check_and_release_sites',
    frequency: Duration(minutes: 10),
    backoffPolicy: BackoffPolicy.exponential,
  );
}

void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == 'check_and_release_sites') {
      final count = await AutoReleaseService().checkAndReleaseSites();
      debugPrint('Auto-released $count sites');
    }
    return true;
  });
}
```

### Where Notifications Sent
1. **Dispatch:** `dispatchSiteEntry()` calls `siteAssigned()`
2. **Claim:** `claim_site_visit` RPC creates notification automatically
3. **Auto-release:** `AutoReleaseService._releaseSite()` calls `siteAutoReleased()`

---

## 6. Database Queries for Testing

### Verify All Columns Exist
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'mmp_site_entries'
ORDER BY ordinal_position;
```

Expected columns include:
- verified_by, verified_at
- dispatched_by, dispatched_at
- accepted_by, accepted_at
- claimed_by, claimed_at
- enumerator_fee, transport_fee, cost
- updated_at

### Verify RPC Function Exists
```sql
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'claim_site_visit';
```

### Test RPC Function
```sql
-- Test as authenticated user
SELECT claim_site_visit(
  'site-uuid'::uuid,
  'user-uuid'::uuid
);

-- Returns:
-- {
--   "success": true,
--   "site_name": "Site A",
--   "enumerator_fee": 75.00,
--   "transport_fee": 50.00,
--   "total_payout": 125.00,
--   "claimed_at": "2025-12-16T..."
-- }
```

### Verify Classifications
```sql
SELECT user_id, classification_level, role_scope, is_active
FROM user_classifications
WHERE is_active = true;

SELECT classification_level, role_scope, site_visit_base_fee_cents, complexity_multiplier
FROM classification_fee_structures
WHERE is_active = true;
```

---

## 7. File Locations Reference

**New Files Created:**
```
supabase/migrations/
├── 20250120_add_tracking_columns_to_mmp_site_entries.sql (NEW)
├── 20250125_add_accepted_columns_to_mmp_site_entries.sql (NEW)
├── 20251121_add_mmp_site_entries_cost_columns.sql (NEW)
├── 20251123_user_classification_system.sql (NEW)
└── 20251128_fix_claim_enumerator_fee.sql (NEW)

lib/services/
└── auto_release_service.dart (NEW)

Documentation/
├── SITE_VISIT_RECEIPT_IMPLEMENTATION_AUDIT.md (NEW)
├── IMPLEMENTATION_QUICK_GUIDE.md (NEW)
└── CODE_IMPLEMENTATION_DETAILS.md (THIS FILE)
```

**Files Updated:**
```
lib/widgets/
└── claim_site_button.dart (UPDATED: Use RPC instead of direct DB)

lib/services/
├── notification_trigger_service.dart (UPDATED: Added siteAssigned method)
└── site_visit_service.dart (UPDATED: Added notification sending to dispatchSiteEntry)
```

---

## 8. Rollback Instructions (If Needed)

If you need to rollback changes:

### Revert ClaimSiteButton
```dart
// Change RPC call back to direct update:
await supabase
    .from('mmp_site_entries')
    .update({
      'claimed_by': userId,
      'claimed_at': DateTime.now().toIso8601String(),
      'status': 'claimed',
    })
    .eq('id', widget.siteEntryId);
```

### Revert Site Service
```dart
// Remove notification sending from dispatchSiteEntry:
// Just remove the if block that calls siteAssigned()
```

### Drop Migrations
```sql
-- In Supabase, reverse order:
DROP FUNCTION IF EXISTS public.claim_site_visit(...);
DROP TABLE IF EXISTS public.classification_fee_structures;
DROP TABLE IF EXISTS public.user_classifications;
DROP TYPE IF EXISTS classification_level;
DROP TYPE IF EXISTS classification_role_scope;
ALTER TABLE public.mmp_site_entries DROP COLUMN IF EXISTS enumerator_fee;
ALTER TABLE public.mmp_site_entries DROP COLUMN IF EXISTS transport_fee;
ALTER TABLE public.mmp_site_entries DROP COLUMN IF EXISTS cost;
ALTER TABLE public.mmp_site_entries DROP COLUMN IF EXISTS claimed_by;
ALTER TABLE public.mmp_site_entries DROP COLUMN IF EXISTS claimed_at;
ALTER TABLE public.mmp_site_entries DROP COLUMN IF EXISTS accepted_by;
ALTER TABLE public.mmp_site_entries DROP COLUMN IF EXISTS accepted_at;
```

---

## 9. Performance Considerations

### Indexes Added
```sql
-- For faster queries
CREATE INDEX idx_mmp_site_entries_claimed_by ON mmp_site_entries(claimed_by);
CREATE INDEX idx_mmp_site_entries_claimed_at ON mmp_site_entries(claimed_at);
CREATE INDEX idx_mmp_site_entries_accepted_by ON mmp_site_entries(accepted_by);
CREATE INDEX idx_user_classifications_user_id ON user_classifications(user_id);
CREATE INDEX idx_classification_fee_structures_level_scope ON classification_fee_structures(classification_level, role_scope);
```

### Query Performance
- Claim RPC uses `FOR UPDATE SKIP LOCKED` for optimal locking
- Auto-release query limited to 500 sites per run
- Classification lookup is indexed for fast retrieval

---

## 10. Monitoring & Debugging

### Check Auto-Release Activity
```sql
SELECT id, site_name, accepted_by, status, additional_data->>'autorelease_triggered'
FROM mmp_site_entries
WHERE additional_data->>'autorelease_triggered' = 'true'
ORDER BY updated_at DESC
LIMIT 10;
```

### Check Recent Claims
```sql
SELECT id, site_name, claimed_by, claimed_at, enumerator_fee, transport_fee, cost
FROM mmp_site_entries
WHERE claimed_by IS NOT NULL
ORDER BY claimed_at DESC
LIMIT 10;
```

### Check Sent Notifications
```sql
SELECT user_id, title, message, created_at
FROM notifications
WHERE title LIKE '%Site%'
ORDER BY created_at DESC
LIMIT 20;
```

---

**Last Updated:** December 16, 2025  
**Status:** ✅ Ready for Implementation
