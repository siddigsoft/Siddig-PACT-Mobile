# ✅ Data Collector Site Receipt - Deployment Checklist

**Start Date:** December 16, 2025  
**Target Completion:** December 19, 2025

---

## 📋 PRE-DEPLOYMENT

### Phase 1: Code Review (Today)
- [ ] Read `DEPLOYMENT_SUMMARY.md` (overview)
- [ ] Read `IMPLEMENTATION_QUICK_GUIDE.md` (instructions)
- [ ] Review `CODE_IMPLEMENTATION_DETAILS.md` (technical details)
- [ ] Review `SITE_VISIT_RECEIPT_IMPLEMENTATION_AUDIT.md` (comprehensive analysis)

### Phase 2: Verify Files Exist
- [ ] `supabase/migrations/20250120_add_tracking_columns_to_mmp_site_entries.sql`
- [ ] `supabase/migrations/20250125_add_accepted_columns_to_mmp_site_entries.sql`
- [ ] `supabase/migrations/20251121_add_mmp_site_entries_cost_columns.sql`
- [ ] `supabase/migrations/20251123_user_classification_system.sql`
- [ ] `supabase/migrations/20251128_fix_claim_enumerator_fee.sql`
- [ ] `lib/services/auto_release_service.dart`
- [ ] `lib/widgets/claim_site_button.dart` (updated)
- [ ] `lib/services/notification_trigger_service.dart` (updated)
- [ ] `lib/services/site_visit_service.dart` (updated)

---

## 🗄️ DATABASE SETUP

### Step 1: Apply Migrations (IN ORDER)
**Location:** Supabase SQL Editor → Run each file

- [ ] **Migration 1:** `20250120_add_tracking_columns_to_mmp_site_entries.sql`
  - Adds: verified_by, verified_at, dispatched_by, dispatched_at, updated_at
  - Verification: `SELECT COUNT(*) FROM pg_indexes WHERE tablename='mmp_site_entries' AND indexname LIKE '%verified%';`

- [ ] **Migration 2:** `20250125_add_accepted_columns_to_mmp_site_entries.sql`
  - Adds: accepted_by, accepted_at, claimed_by, claimed_at
  - Verification: `SELECT column_name FROM information_schema.columns WHERE table_name='mmp_site_entries' AND column_name='claimed_by';`

- [ ] **Migration 3:** `20251121_add_mmp_site_entries_cost_columns.sql`
  - Adds: enumerator_fee, transport_fee, cost
  - Verification: `SELECT * FROM mmp_site_entries LIMIT 1;` (check new columns exist)

- [ ] **Migration 4:** `20251123_user_classification_system.sql`
  - Creates: user_classifications, classification_fee_structures tables
  - Creates: classification_level, classification_role_scope enum types
  - Verification: `SELECT COUNT(*) FROM classification_fee_structures;` (should be >0)

- [ ] **Migration 5:** `20251128_fix_claim_enumerator_fee.sql`
  - Creates: claim_site_visit() RPC function
  - Verification: `SELECT routine_name FROM information_schema.routines WHERE routine_name='claim_site_visit';`

### Step 2: Verify All Migrations Applied
```sql
-- Run this to verify all columns exist:
SELECT 
  COUNT(*) as total_columns
FROM information_schema.columns 
WHERE table_name = 'mmp_site_entries' 
AND column_name IN (
  'verified_by', 'verified_at', 'dispatched_by', 'dispatched_at', 
  'updated_at', 'accepted_by', 'accepted_at', 'claimed_by', 'claimed_at',
  'enumerator_fee', 'transport_fee', 'cost'
);
-- Result should be: 12
```

- [ ] Verification passed (12 columns found)

### Step 3: Populate Classification Data
```sql
-- Verify default classifications were inserted:
SELECT COUNT(*) FROM classification_fee_structures;
-- Should return: 9 (default fee structures)

-- Verify fee structure types:
SELECT DISTINCT classification_level, role_scope FROM classification_fee_structures ORDER BY 1, 2;
```

- [ ] Default fee structures exist (9 rows)
- [ ] Fee structure query returns expected classifications

### Step 4: Test RPC Function
```sql
-- Test that RPC function works (as authenticated user):
SELECT claim_site_visit(
  'test-uuid'::uuid,
  'test-user-uuid'::uuid
);
```

- [ ] RPC function can be called
- [ ] Returns JSONB response (even if with error about test UUID)

---

## 👥 DATA SETUP

### Step 5: Assign Classifications to Test Collectors
**Location:** Supabase → Table Editor → user_classifications

For each test data collector:
```sql
INSERT INTO user_classifications (
  user_id, 
  classification_level, 
  role_scope, 
  is_active
)
VALUES (
  'collector-uuid',
  'intermediate',     -- or 'junior', 'senior', 'lead'
  'field_officer',    -- or 'team_leader', 'supervisor', 'coordinator'
  true
);
```

- [ ] Test collector 1 has classification assigned
- [ ] Test collector 2 has classification assigned
- [ ] Test collector 3 has classification assigned (optional)

### Step 6: Verify Classifications in Database
```sql
SELECT user_id, classification_level, role_scope, is_active 
FROM user_classifications 
WHERE is_active = true;
```

- [ ] Classifications visible in query results
- [ ] At least 1 test collector has a classification

---

## 📱 APPLICATION UPDATES

### Step 7: Update App Code
- [ ] `lib/widgets/claim_site_button.dart` - Updated to use RPC
  - Verify: Calls `supabase.rpc('claim_site_visit', ...)` instead of direct update
  
- [ ] `lib/services/notification_trigger_service.dart` - Added siteAssigned()
  - Verify: Method `siteAssigned()` exists and callable
  
- [ ] `lib/services/site_visit_service.dart` - Enhanced dispatchSiteEntry()
  - Verify: Method calls `NotificationTriggerService().siteAssigned()`
  
- [ ] `lib/services/auto_release_service.dart` - New service created
  - Verify: File exists and compiles without errors

### Step 8: Register Background Task
**Location:** `lib/main.dart` or `lib/services/app_config_service.dart`

```dart
// In initialization:
await Workmanager().initialize(callbackDispatcher);

// Register periodic task:
await Workmanager().registerPeriodicTask(
  'auto_release_sites',
  'check_and_release_sites',
  frequency: Duration(minutes: 10),
  backoffPolicy: BackoffPolicy.exponential,
);

// In callback:
Workmanager().executeTask((taskName, inputData) async {
  if (taskName == 'check_and_release_sites') {
    final count = await AutoReleaseService().checkAndReleaseSites();
    debugPrint('Auto-released $count sites');
  }
  return true;
});
```

- [ ] Background task registered
- [ ] Auto-release runs every 10 minutes

### Step 9: Build & Test App
```bash
# Run your Flutter app build
flutter pub get
flutter analyze
flutter build apk  # or ios
```

- [ ] No compilation errors
- [ ] No analysis warnings related to new code

---

## 🧪 TESTING

### Step 10: End-to-End Testing - Manual Flow

#### Test 1: Dispatch to Collector
1. Create/upload MMP file
2. Verify MMP site entry
3. Set transport budget
4. **Dispatch to collector:** `dispatchSiteEntry(siteId, coordinatorId, toDataCollectorId)`
   - [ ] Collector receives notification in app
   - [ ] Notification includes fee breakdown
   - [ ] Site visible in "Available" list

#### Test 2: Claim Site
1. Open app as test collector
2. Find dispatched site
3. Click "Claim Site"
4. **Expected flow:**
   - [ ] Button shows loading state
   - [ ] RPC function called (check logs)
   - [ ] Site status changes to "Accepted"
   - [ ] Collector sees success notification
   - [ ] Notification shows correct fee breakdown:
     - enumerator_fee (from classification)
     - transport_fee (set at dispatch)
     - total_payout (sum of both)

#### Test 3: View Claimed Site
1. Open "My Sites" or "Claimed" tab
2. **Expected:**
   - [ ] Claimed site visible
   - [ ] Shows correct fees
   - [ ] Status = "Accepted"
   - [ ] Can start visit

#### Test 4: Verify Database Updates
```sql
-- After claiming site:
SELECT 
  id, site_name, status, claimed_by, claimed_at, 
  enumerator_fee, transport_fee, cost,
  additional_data->>'claim_fee_calculation' as fee_calc
FROM mmp_site_entries 
WHERE id = 'claimed-site-uuid';
```

- [ ] claimed_by = collector's user ID
- [ ] claimed_at has recent timestamp
- [ ] enumerator_fee is non-zero
- [ ] cost = enumerator_fee + transport_fee
- [ ] fee_calc contains calculation details

### Step 11: Race Condition Testing
**Purpose:** Verify FOR UPDATE SKIP LOCKED works

1. Setup: 2 collectors, 1 dispatched site
2. Have both collectors attempt to claim same site simultaneously
3. **Expected:**
   - [ ] One claim succeeds (gets lock)
   - [ ] One claim fails with message "ALREADY_CLAIMED" or "CLAIM_IN_PROGRESS"
   - [ ] Site only marked as claimed once
   - [ ] Both collectors see appropriate notifications

### Step 12: Auto-Release Testing
**Requires:** Manual database manipulation (for testing purposes)

```sql
-- Set autorelease deadline to past time
UPDATE mmp_site_entries 
SET additional_data = jsonb_set(
  additional_data,
  '{autorelease_at}',
  to_jsonb(NOW() - interval '1 hour')
)
WHERE id = 'test-site-uuid' 
AND status = 'Accepted'
AND accepted_by IS NOT NULL;
```

1. Manually set autorelease_at to past time
2. Wait for background task to run (or call manually)
3. **Expected:**
   - [ ] Site status changed back to "Dispatched"
   - [ ] accepted_by and claimed_by cleared
   - [ ] Former assignee receives auto-release notification
   - [ ] Site available for other collectors to claim

### Step 13: Notification Testing
```sql
-- Check notifications were created
SELECT user_id, title, message, type, created_at 
FROM notifications 
WHERE related_entity_type = 'siteVisit'
ORDER BY created_at DESC 
LIMIT 10;
```

- [ ] "Site Assigned" notifications created when dispatched
- [ ] "Site Claimed Successfully" notifications created after claim
- [ ] "Site Released" notifications created on auto-release
- [ ] Correct message content in each

---

## 📊 PERFORMANCE & MONITORING

### Step 14: Check Query Performance
```sql
-- Verify indexes created
SELECT indexname FROM pg_indexes 
WHERE tablename = 'mmp_site_entries' 
ORDER BY indexname;
```

- [ ] idx_mmp_site_entries_claimed_by exists
- [ ] idx_mmp_site_entries_accepted_by exists
- [ ] idx_mmp_site_entries_status exists

### Step 15: Monitor Logs
In your application logs, look for:
- [ ] `📤 Dispatching site entry:` - Dispatch starts
- [ ] `✅ Notification sent to collector:` - Notification sent
- [ ] `✅ Site entry dispatched successfully` - Dispatch complete
- [ ] Claims: No errors in `_claimSiteOnline()`
- [ ] Auto-release: `✓ No sites to check for auto-release` or `✅ Auto-released X sites`

---

## 🚀 PRODUCTION DEPLOYMENT

### Step 16: Backup Database
- [ ] Supabase backup created before migrations
- [ ] Backup location noted for rollback if needed

### Step 17: Deploy Migrations to Production
- [ ] Connect to production Supabase instance
- [ ] Run all 5 migrations in order (same process as testing)
- [ ] Verify all migrations succeeded with no errors

### Step 18: Deploy Code to Production
- [ ] Code changes merged to main branch
- [ ] Build signed APK/IPA
- [ ] Deploy to app stores or internal distribution
- [ ] Notify QA team of deployment

### Step 19: Production Smoke Tests
1. Create test MMP
2. Dispatch to test collector
3. Verify notification received
4. Claim site
5. Verify status and fees
   - [ ] Dispatch works
   - [ ] Notification received
   - [ ] Claim succeeds
   - [ ] Fees calculated correctly

### Step 20: Monitor Production
**First 24 hours:**
- [ ] No error spike in Supabase logs
- [ ] RPC function executing successfully
- [ ] Notifications being sent
- [ ] Collectors can claim sites
- [ ] Auto-release background task running

**Ongoing:**
- [ ] Monitor RPC function performance
- [ ] Track notification delivery rates
- [ ] Monitor auto-release execution
- [ ] Check for any edge cases or bugs

---

## ✅ SIGN-OFF

### Development Team Sign-Off
- [ ] Code review completed
- [ ] All tests passed
- [ ] Documentation reviewed
- [ ] Ready for QA

### QA Sign-Off
- [ ] Manual testing completed
- [ ] Automated tests passed (if applicable)
- [ ] Performance acceptable
- [ ] No critical bugs found
- [ ] Ready for production

### Product Manager Sign-Off
- [ ] Feature meets requirements
- [ ] User experience acceptable
- [ ] Ready to deploy to users
- [ ] Communicated to stakeholders

---

## 📞 Support & Rollback

### If Issues Found
1. Review logs for error messages
2. Check database for unexpected states
3. Consult `SITE_VISIT_RECEIPT_IMPLEMENTATION_AUDIT.md` for troubleshooting
4. For critical issues, execute rollback (see CODE_IMPLEMENTATION_DETAILS.md)

### Emergency Rollback
```sql
-- Only if absolutely necessary
DROP FUNCTION IF EXISTS public.claim_site_visit(...);
-- Keep data; drop migrations in reverse order if needed
-- Restore from backup if data corruption suspected
```

- [ ] Rollback procedure documented and tested

---

## 📝 Final Notes

- Total migration scope: **5 database migrations**
- New service: **1 (auto_release_service.dart)**
- Updated services: **3 (notification, site_visit, claim_button)**
- Deployment time estimate: **2-3 hours** (including testing)
- Rollback time estimate: **30 minutes** (if needed)

**This implementation ensures:**
- ✅ Data collectors receive site notifications
- ✅ Atomic claiming prevents race conditions
- ✅ Fees calculated from classification
- ✅ Auto-release recovers unclaimed sites
- ✅ Complete end-to-end flow works

---

**Checklist Version:** 1.0  
**Last Updated:** December 16, 2025  
**Status:** ✅ Ready for Deployment

**Start Here:** Follow each section in order ↑
