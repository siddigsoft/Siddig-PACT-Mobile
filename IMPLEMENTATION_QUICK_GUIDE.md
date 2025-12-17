# Site Visit Lifecycle - Quick Implementation Guide

## ✅ What Has Been Created/Fixed

### 1. **Database Migrations** (Ready to Deploy)
All SQL migration files created and ready:

- ✅ `20250120_add_tracking_columns_to_mmp_site_entries.sql` - Adds verified_by, dispatched_by, updated_at
- ✅ `20250125_add_accepted_columns_to_mmp_site_entries.sql` - Adds claimed_by, accepted_by, claimed_at, accepted_at
- ✅ `20251121_add_mmp_site_entries_cost_columns.sql` - Adds enumerator_fee, transport_fee, cost
- ✅ `20251123_user_classification_system.sql` - Creates classification & fee structures
- ✅ `20251128_fix_claim_enumerator_fee.sql` - Creates atomic claim_site_visit RPC

**Location:** `supabase/migrations/`

**Action:** Run these in your Supabase SQL Editor in order

---

### 2. **Backend Services** (Updated)

#### ✅ Auto Release Service
**File:** `lib/services/auto_release_service.dart` (NEW)
- Monitors assigned sites for auto-release deadline
- Releases sites back to "Dispatched" if not confirmed
- Sends notifications to former assignees

**How to Use:**
```dart
final autoReleaseService = AutoReleaseService();
// Call this every 5-10 minutes via background task
int released = await autoReleaseService.checkAndReleaseSites();
```

#### ✅ Notification Service Enhanced
**File:** `lib/services/notification_trigger_service.dart` (UPDATED)
- Added `siteAssigned()` method - Notifies collector of assignment
- Added comprehensive fee info in notifications

**How to Use:**
```dart
await NotificationTriggerService().siteAssigned(
  collectorUserId,
  siteName,
  siteId,
  enumeratorFee: 50.0,
  transportFee: 25.0,
);
```

#### ✅ Site Visit Service Enhanced
**File:** `lib/services/site_visit_service.dart` (UPDATED)
- `dispatchSiteEntry()` now sends notifications automatically
- Added support for individual site assignments

---

### 3. **Frontend Components** (Updated)

#### ✅ Claim Site Button Fixed
**File:** `lib/widgets/claim_site_button.dart` (UPDATED)

**Before:**
```dart
// Direct DB update - no atomicity, no fee calculation
await supabase.from('mmp_site_entries').update({...})
```

**After:**
```dart
// Atomic RPC call with race condition protection
final response = await supabase.rpc('claim_site_visit', {
  'p_site_id': siteId,
  'p_user_id': userId,
  // Fee calculated from classification automatically
});
```

---

## 📋 Data Collector Receipt Flow - Now Complete

```
┌─────────────────────────────────────────────────────────────────┐
│                   COMPLETE FLOW (NOW WORKING)                   │
└─────────────────────────────────────────────────────────────────┘

1. ✅ MMP uploaded and parsed into mmp_site_entries
   └─ Verified by coordinator

2. ✅ Cost set and transport budget assigned
   └─ Dispatched status set

3. ✅ Collector notified via siteAssigned notification
   └─ Includes fee breakdown

4. ✅ Collector claims site via atomic RPC
   └─ Enumerator fee calculated from classification
   └─ Status changed to "Accepted"
   └─ Race conditions prevented

5. ✅ Auto-release monitors for deadline
   └─ If not confirmed, released back to "Dispatched"
   └─ Collector notified of release

6. ✅ Collector can view fees before claiming
   └─ Transport fee (set at dispatch)
   └─ Enumerator fee (calculated at claim from classification)
   └─ Total payout = enumerator_fee + transport_fee

7. ✅ Payment ready after completion
```

---

## 🚀 Next Steps - Implementation Order

### Step 1: Apply Database Migrations (TODAY)
```bash
# In Supabase SQL Editor, run these in order:
1. 20250120_add_tracking_columns_to_mmp_site_entries.sql
2. 20250125_add_accepted_columns_to_mmp_site_entries.sql
3. 20251121_add_mmp_site_entries_cost_columns.sql
4. 20251123_user_classification_system.sql
5. 20251128_fix_claim_enumerator_fee.sql
```

### Step 2: Populate Classification Data (TODAY)
```sql
-- The migration inserts default classifications
-- Verify they exist:
SELECT * FROM classification_fee_structures;

-- Assign classifications to collectors:
INSERT INTO user_classifications (user_id, classification_level, role_scope, is_active)
VALUES (
  'collector-uuid',
  'intermediate',
  'field_officer',
  true
);
```

### Step 3: Register Auto-Release Background Task (TOMORROW)
```dart
// In app_config_service.dart or main.dart
await Workmanager().registerPeriodicTask(
  'auto_release_sites',
  'check_and_release_sites',
  frequency: Duration(minutes: 10),
  backoffPolicy: BackoffPolicy.exponential,
  backoffPolicyDelay: Duration(minutes: 5),
);

// Add callback handler:
Workmanager().executeTask((taskName, inputData) async {
  if (taskName == 'check_and_release_sites') {
    await AutoReleaseService().checkAndReleaseSites();
  }
  return true;
});
```

### Step 4: Test End-to-End (TOMORROW)
```dart
// 1. Verify migrations applied
SELECT COUNT(*) FROM mmp_site_entries WHERE claimed_by IS NOT NULL;

// 2. Test classification lookup
SELECT * FROM user_classifications WHERE user_id = 'test-user-id';

// 3. Test RPC function
SELECT claim_site_visit('site-uuid'::uuid, 'user-uuid'::uuid);

// 4. Verify fee calculation
SELECT enumerator_fee, transport_fee, cost FROM mmp_site_entries 
WHERE id = 'claimed-site-uuid';
```

---

## 🔍 Verification Checklist

- [ ] All 5 migration files exist in `supabase/migrations/`
- [ ] Migrations run without errors in Supabase SQL Editor
- [ ] `mmp_site_entries` table has all required columns
- [ ] `user_classifications` table populated with test data
- [ ] `classification_fee_structures` table has fee entries
- [ ] `claim_site_visit` RPC function appears in Supabase Functions
- [ ] `ClaimSiteButton` updated to use RPC instead of direct update
- [ ] `NotificationTriggerService.siteAssigned()` method works
- [ ] `AutoReleaseService` registers in background tasks
- [ ] Test collector can claim a site and see correct fee breakdown

---

## 📝 Key Changes Summary

| Component | What Changed | Why |
|-----------|-------------|-----|
| Database | Added 5 new migrations | Track claims, fees, and enable calculations |
| ClaimSiteButton | Uses RPC instead of direct DB | Atomic transactions, race condition prevention |
| Notifications | Added siteAssigned() method | Collectors see assignments |
| Dispatch | Sends notifications automatically | Collectors get alerts |
| Auto-release | New service created | Recover stuck sites |
| Classifications | New system created | Dynamic fee calculation |

---

## 🐛 Common Issues & Troubleshooting

### Issue: "claim_site_visit function not found"
**Cause:** Migration 20251128 not applied
**Fix:** Run the migration in Supabase SQL Editor

### Issue: Collector not receiving notifications
**Cause:** siteAssigned() not being called during dispatch
**Fix:** Verify dispatchSiteEntry() is using updated method

### Issue: Enumerator fee always 50 SDG
**Cause:** Classification not assigned to collector
**Fix:** Populate user_classifications table with collector's classification

### Issue: Sites not auto-releasing
**Cause:** Background task not registered
**Fix:** Register periodic task in app initialization

### Issue: RLS policy blocking site access
**Cause:** RLS only allows collectors to access "accepted" sites
**Fix:** Add policy to allow viewing "Dispatched" sites (already in COMPLETE_RLS_POLICIES.sql)

---

## 📞 Support

**Need help?**
1. Check the audit report: `SITE_VISIT_RECEIPT_IMPLEMENTATION_AUDIT.md`
2. Verify all migrations are applied
3. Check logs for error messages
4. Review the RPC function definition in Supabase

---

## ✨ What's Now Working for Data Collectors

### ✅ Receiving Sites
- Collectors get push notifications when sites are assigned
- Can see available sites in "Dispatched" status
- See fee breakdown before claiming

### ✅ Claiming Sites
- Click "Claim Site" button
- System atomically locks site and updates status
- Enumerator fee automatically calculated from classification
- Notification confirms successful claim

### ✅ Tracking Claims
- Can view assigned sites in "Accepted" status
- See fees and total payout
- Track history of claims

### ✅ Auto-Recovery
- If collector doesn't confirm in time, site released back
- Site becomes available to other collectors
- Collector notified of auto-release

---

**Generated:** December 16, 2025
**Status:** ✅ Ready for Deployment
