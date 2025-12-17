# Site Visit Receipt Flow - Implementation Audit
**Date**: December 16, 2025  
**Status**: ⚠️ INCOMPLETE - Critical gaps found in data collector receipt flow

---

## Executive Summary

The implementation document outlines a comprehensive site visit lifecycle (MMP upload → dispatch → claim → payment), but your current codebase is **missing critical components** that prevent data collectors from receiving site visits. The flow is incomplete and data collectors cannot properly:

1. **Claim/Accept** dispatched site visits
2. **Receive notifications** when sites are assigned
3. **Calculate fees** based on their classification
4. **Auto-release** sites if not claimed within timeframe

---

## Critical Gaps & Issues

### 1. ❌ **CRITICAL: Missing `claim_site_visit` RPC Function**

**Document Requirement:**
```sql
CREATE OR REPLACE FUNCTION claim_site_visit(
  p_site_id UUID,
  p_user_id UUID,
  p_enumerator_fee NUMERIC DEFAULT NULL,
  ...
)
```

**Current Status:** NOT IMPLEMENTED
- The RPC function is completely missing from all migration files
- ClaimSiteButton.dart directly updates `mmp_site_entries` instead of calling the atomic RPC
- This bypasses critical locking and fee calculations

**Impact:** 
- ❌ No atomic transaction protection - race conditions possible
- ❌ Enumerator fees not calculated from classification
- ❌ Cannot handle concurrent claims

**Fix Required:**
```sql
-- Add to supabase/migrations/[timestamp]_create_claim_site_visit_rpc.sql
-- Implement the full claim_site_visit RPC from the document (lines showing 20251128_fix_claim_enumerator_fee.sql)
```

---

### 2. ❌ **CRITICAL: Database Schema Missing Key Columns**

**Documented Columns Not Found:**

| Column | Purpose | Status |
|--------|---------|--------|
| `claimed_by` | User ID who claimed the site | ✅ Found in model |
| `claimed_at` | Timestamp of claim | ✅ Found in model |
| `accepted_by` | Data collector assigned | ✅ Found in model |
| `accepted_at` | Acceptance timestamp | ✅ Found in model |
| `enumerator_fee` | Fee calculated from classification | ✅ Found in model |
| `transport_fee` | Transport budget | ✅ Found in model |
| `cost` | Total cost | ✅ Found in model |
| `dispatched_by` | Who dispatched | ✅ Found in model |
| `dispatched_at` | Dispatch timestamp | ✅ Found in model |
| `verified_by` | Who verified | ✅ Found in model |
| `verified_at` | Verification timestamp | ✅ Found in model |
| `updated_at` | Last update timestamp | ✅ Found in model |

**Status:** Most columns referenced in code but **migrations may not be applied**

**Action Required:**
- Verify all migration files from the document are in `supabase/migrations/`
- Run missing migrations:
  - `20250120_add_tracking_columns_to_mmp_site_entries.sql`
  - `20250125_add_accepted_columns_to_mmp_site_entries.sql`
  - `20251121_add_mmp_site_entries_cost_columns.sql`

---

### 3. ❌ **ClaimSiteButton Not Using Atomic RPC**

**Current Implementation** (`lib/widgets/claim_site_button.dart:120`):
```dart
const { error: costError } = await supabase
  .from('mmp_site_entries')
  .update({
    'claimed_by': userId,
    'claimed_at': DateTime.now().toIso8601String(),
    'status': 'claimed',
    'updated_at': DateTime.now().toIso8601String(),
  })
  .eq('id', widget.siteEntryId)
  .select()
  .maybeSingle();
```

**Problems:**
- ❌ Direct table update instead of RPC call
- ❌ No race condition prevention (SKIP LOCKED)
- ❌ Enumerator fee NOT calculated
- ❌ No fee breakdown returned to UI

**Required Fix:**
```dart
// Replace with atomic RPC call:
final { data, error } = await supabase.rpc('claim_site_visit', {
  'p_site_id': widget.siteEntryId,
  'p_user_id': userId,
  'p_enumerator_fee': feeBreakdown.enumeratorFee,
  'p_total_cost': feeBreakdown.totalPayout,
  'p_classification_level': feeBreakdown.classificationLevel,
  'p_role_scope': feeBreakdown.roleScope,
  'p_fee_source': feeBreakdown.feeSource
});
```

---

### 4. ❌ **Missing `useClaimFeeCalculation` Hook**

**Document Requirement:**
```dart
export interface ClaimFeeBreakdown {
  transportBudget: number;
  enumeratorFee: number;
  totalPayout: number;
  classificationLevel: ClassificationLevel | null;
  roleScope: ClassificationRoleScope | null;
  feeSource: 'classification' | 'default';
  currency: string;
}

export function useClaimFeeCalculation(): UseClaimFeeCalculationResult
```

**Current Status:** NOT IMPLEMENTED
- No fee calculation hook exists
- No classification lookup implemented
- No fee structure tables referenced

**Missing Files:**
- `lib/hooks/use_claim_fee_calculation.dart` (or equivalent)
- Classification system not implemented

**Fix Required:**
Create the fee calculation logic that:
```dart
// 1. Fetch user's active classification
// 2. Look up fee structure from classification_fee_structures table
// 3. Calculate: enumeratorFee = base_fee * multiplier
// 4. Return breakdown with all components
```

---

### 5. ❌ **Missing Notification Trigger for Site Assignment**

**Document Requires:**
```dart
NotificationTriggerService.siteAssigned(userId, siteName, siteId)
NotificationTriggerService.siteClaimNotification(...)
```

**Current Status:** ✅ Partial - NotificationTriggerService exists

**Found Methods** (`lib/services/notification_trigger_service.dart`):
- `send(options)` ✅
- `_shouldSendNotification(...)` ✅

**Missing Methods:**
- ❌ `siteAssigned(userId, siteName, siteId)` - NOT FOUND
- ❌ `siteClaimNotification(...)` - NOT FOUND
- ❌ `siteAutoReleased(...)` - Defined but not integrated

**Impact:**
- ❌ Collectors not notified when sites are assigned
- ❌ Collectors don't receive claim confirmations
- ❌ No auto-release notifications

**Fix:** Add these helper methods to NotificationTriggerService:
```dart
Future<void> siteAssigned(String userId, String siteName, String siteId) async {
  await send(NotificationTriggerOptions(
    userId: userId,
    title: 'Site Assigned',
    message: 'You have been assigned to $siteName',
    category: NotificationCategory.assignment,
    priority: NotificationPriority.high,
    link: '/site-visits/$siteId',
    relatedEntityId: siteId,
    relatedEntityType: RelatedEntityType.siteVisit,
  ));
}

Future<void> siteClaimNotification(String userId, String siteName, double fee) async {
  await send(NotificationTriggerOptions(
    userId: userId,
    title: 'Site Claimed Successfully',
    message: 'You claimed $siteName. Fee: $fee SDG',
    category: NotificationCategory.transaction,
    priority: NotificationPriority.high,
  ));
}
```

---

### 6. ❌ **Missing Auto-Release Service**

**Document Requirement:**
```dart
// Monitors sites for auto-release if not confirmed within deadline
const sitesToRelease = pendingSites.filter(site => {
  const visitData = site.visit_data as SiteVisitData | null;
  if (!visitData?.autorelease_at) return false;
  if (visitData.confirmation_status !== 'pending') return false;
  return shouldAutoRelease(visitData.autorelease_at, ...);
});
```

**Current Status:** NOT IMPLEMENTED
- No auto-release service exists
- No scheduled job to check timeouts
- No mechanism to release sites after deadline

**Impact:**
- ❌ Sites stay assigned to collectors indefinitely
- ❌ No recovery if collector becomes unavailable
- ❌ No reallocation of unclaimed sites

**Fix Required:**
Create `lib/services/auto_release_service.dart`:
```dart
class AutoReleaseService {
  Future<void> checkAndReleaseSites() async {
    // Query sites where:
    // - status = 'assigned'
    // - autorelease_at < now()
    // - confirmation_status = 'pending'
    
    // For each site:
    // - Update status back to 'Dispatched'
    // - Clear assigned_to, accepted_by
    // - Create notification: siteAutoReleased()
  }
}

// Schedule this as a background task (already has workmanager setup)
```

---

### 7. ❌ **Dispatch Flow Not Sending Notifications to Collectors**

**Current Implementation** (`lib/services/site_visit_service.dart:754`):
```dart
Future<void> dispatchSiteEntry(
  String siteEntryId,
  String userId, {
  String? toDataCollectorId,
}) async {
  // Updates DB but NO NOTIFICATION sent
  final updateData = {
    'status': 'Dispatched',
    'dispatched_by': userId,
    'dispatched_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };
  
  if (toDataCollectorId != null) {
    updateData['accepted_by'] = toDataCollectorId; // assigned case
  }
  // ❌ NO notification here!
}
```

**Required Enhancement:**
```dart
Future<void> dispatchSiteEntry(
  String siteEntryId,
  String userId, {
  String? toDataCollectorId,
}) async {
  // ... existing update code ...
  
  // ✅ NEW: Send notification to collectors
  if (toDataCollectorId != null) {
    // Individual assignment
    await NotificationTriggerService().siteAssigned(
      toDataCollectorId,
      siteName,
      siteEntryId,
    );
  } else {
    // Broadcast dispatch to all eligible collectors
    // Query eligible collectors and send bulk notifications
  }
}
```

---

### 8. ⚠️ **Missing Classification & Fee Structure Tables**

**Document References:**
```sql
-- Tables needed but NOT FOUND in migrations:
- user_classifications (classification_level, role_scope, is_active)
- classification_fee_structures (base_fee_cents, complexity_multiplier)
```

**Current Status:** MISSING
- No migration creates these tables
- Fee calculation logic has nowhere to read from

**Fix Required:**
Create migration file: `supabase/migrations/[timestamp]_create_classification_fee_structures.sql`

---

### 9. ⚠️ **RLS Policies May Block Collectors from Receiving Sites**

**Current RLS Policy** (`COMPLETE_RLS_POLICIES.sql:40-44`):
```sql
CREATE POLICY "Allow update mmp_site_entries for authenticated"
  ON public.mmp_site_entries
  FOR UPDATE
  USING (auth.uid() = accepted_by::uuid OR accepted_by IS NULL)
  WITH CHECK (auth.uid() = accepted_by::uuid);
```

**Issue:**
- Collectors can only update sites they already accepted (`accepted_by = auth.uid()`)
- When status='Dispatched', `accepted_by` is NULL
- Collectors can UPDATE to claim, but RLS may prevent SELECT/INSERT of new dispatched sites

**Fix:**
Enhance policy to allow viewing dispatched sites:
```sql
CREATE POLICY "Collectors can view dispatched sites"
  ON public.mmp_site_entries
  FOR SELECT
  USING (
    auth.role() = 'authenticated' 
    AND (status = 'Dispatched' OR status = 'Assigned' OR auth.uid() = accepted_by::uuid)
  );
```

---

## Data Collector Receipt Flow - Current State

```
┌─────────────────────────────────────────────────────────────┐
│ MMP UPLOAD → DISPATCH → COLLECTOR RECEIVES → CLAIM → PAYMENT │
└─────────────────────────────────────────────────────────────┘

✅ WORKING:
1. MMP uploaded and parsed into mmp_site_entries
2. Site verified and cost set (dispatchSiteEntry method exists)
3. Site status changed to 'Dispatched'

❌ BROKEN - Collector Cannot Receive:
4. ❌ NO notification sent to collectors
5. ❌ NO way for collector to see fees before claiming
6. ❌ ClaimSiteButton doesn't call atomic RPC
7. ❌ NO enumerator fee calculated from classification
8. ❌ NO atomic locking (race conditions possible)
9. ❌ NO auto-release if not claimed in time
10. ❌ Classification system doesn't exist
```

---

## Implementation Checklist

### Phase 1: Database (Week 1)
- [ ] **Create migration:** `20250120_add_tracking_columns_to_mmp_site_entries.sql`
- [ ] **Create migration:** `20250125_add_accepted_columns_to_mmp_site_entries.sql`
- [ ] **Create migration:** `20251121_add_mmp_site_entries_cost_columns.sql`
- [ ] **Create migration:** Classification & fee structure tables
- [ ] **Update RLS policies** to allow collectors to see dispatched sites
- [ ] **Create migration:** `claim_site_visit` RPC function

### Phase 2: Backend Services (Week 1-2)
- [ ] **Create:** `lib/services/auto_release_service.dart`
- [ ] **Update:** `NotificationTriggerService` with site assignment methods
- [ ] **Create:** Fee calculation service/hook
- [ ] **Integrate:** Classifications lookup

### Phase 3: Frontend (Week 2)
- [ ] **Update:** `ClaimSiteButton` to call RPC instead of direct update
- [ ] **Create:** Fee display component showing breakdown
- [ ] **Update:** Dispatch logic to send notifications
- [ ] **Add:** Site assignment notifications to collectors
- [ ] **Create:** Auto-release background task

### Phase 4: Testing & QA (Week 3)
- [ ] Unit tests for RPC atomicity
- [ ] End-to-end test: dispatch → collector claim → payment
- [ ] Concurrent claim test (multiple collectors)
- [ ] Auto-release timeout test
- [ ] Notification delivery test

---

## Recommended Priority Fixes

### 🔴 Critical (Do First)
1. **Create `claim_site_visit` RPC** - Without this, atomic claiming doesn't work
2. **Add notification methods** - Collectors can't see assignments
3. **Implement fee calculation** - Collectors don't know what they're claiming

### 🟠 High (Do Soon)  
4. Create auto-release service
5. Update RLS policies for site visibility
6. Create classification tables

### 🟡 Medium (Do Before Launch)
7. Update ClaimSiteButton to use RPC
8. Add fee display in UI
9. Integrate background tasks

---

## File References for Implementation

**Files to Create:**
```
supabase/migrations/
  ├── 20250120_add_tracking_columns_to_mmp_site_entries.sql
  ├── 20250125_add_accepted_columns_to_mmp_site_entries.sql
  ├── 20251121_add_mmp_site_entries_cost_columns.sql
  ├── 20251127_first_claim_dispatch_system.sql
  ├── 20251128_fix_claim_enumerator_fee.sql (claim_site_visit RPC)
  └── 20251123_user_classification_system.sql

lib/services/
  ├── auto_release_service.dart (NEW)
  └── fee_calculation_service.dart (NEW)

lib/hooks/
  └── use_claim_fee_calculation.dart (NEW)
```

**Files to Update:**
```
lib/widgets/
  └── claim_site_button.dart (call RPC instead of direct update)

lib/services/
  ├── notification_trigger_service.dart (add siteAssigned, siteClaimNotification methods)
  ├── site_visit_service.dart (add notification call to dispatchSiteEntry)
  └── app_config_service.dart (register auto_release background task)
```

---

## Verification Queries

After implementing all fixes, run these to verify:

```sql
-- 1. Verify RPC exists
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'claim_site_visit';

-- 2. Verify columns exist
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'mmp_site_entries' 
AND column_name IN ('claimed_by', 'claimed_at', 'enumerator_fee', 'dispatched_by');

-- 3. Verify classification tables
SELECT table_name FROM information_schema.tables 
WHERE table_name IN ('user_classifications', 'classification_fee_structures');

-- 4. Verify RLS policies allow site viewing
SELECT policyname FROM pg_policies 
WHERE tablename = 'mmp_site_entries' 
AND policyname LIKE '%Collectors%';
```

---

## Next Steps

1. **Immediately:** Implement the `claim_site_visit` RPC (copy verbatim from document)
2. **This week:** Add classification system and fee calculation
3. **Next week:** Update UI components and add notifications
4. **Before launch:** Full end-to-end testing

Would you like me to:
- ✅ Create the migration files with SQL code?
- ✅ Update the ClaimSiteButton component?
- ✅ Implement the auto-release service?
- ✅ Add the missing notification methods?

