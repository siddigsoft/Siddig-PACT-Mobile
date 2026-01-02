# Data Collector Site Visit Workflow Implementation

## Complete Lifecycle Implementation

The app now follows the exact data collector/enumerator lifecycle as specified:

### Status Flow
```
Dispatched → Claimed (Assigned) → Accepted → In Progress → Completed → Cost Submission → Payment
```

### Phase-by-Phase Implementation

#### PHASE 1: Site Assignment Dispatch
**Status**: `Dispatched`
- Sites appear in "My Visits" panel for all data collectors
- Tiles show site name, location, activity, and scheduled date
- **Action Button**: "Claim Site" (ClaimSiteButton)

**What Happens on Claim**:
1. Calls `claim_site_visit` RPC function (atomic, race-condition protected)
2. Sets `claimed_by` = current user ID
3. Sets `claimed_at` = current timestamp
4. Changes status to `Assigned`
5. Calculates fees based on user classification
6. Shows success message with fee breakdown

**Database Updates**:
```sql
UPDATE mmp_site_entries SET
  claimed_by = 'user-id',
  claimed_at = NOW(),
  status = 'Assigned',
  enumerator_fee = (calculated from user classification),
  transport_fee = (calculated from user classification),
  cost = enumerator_fee + transport_fee
WHERE id = 'site-id' AND status = 'Dispatched';
```

#### PHASE 2: Cost Acknowledgment
**Status**: `Assigned` / `Claimed`
- Site shows in "My Visits" with "Assigned" status
- Shows time remaining warning (2-hour limit)
- **Action Button**: "Accept Assignment" (AcceptAssignmentButton)

**What Happens on Accept**:
1. Shows dialog with fee breakdown:
   - Enumerator Fee: XXX SDG
   - Transport Fee: XXX SDG
   - Total Payout: XXX SDG
2. Requires explicit acknowledgment of costs
3. Sets `accepted_by` = current user ID
4. Sets `accepted_at` = current timestamp
5. Changes status to `Accepted`
6. Starts GPS location tracking

**Database Updates**:
```sql
UPDATE mmp_site_entries SET
  accepted_by = 'user-id',
  accepted_at = NOW(),
  status = 'Accepted'
WHERE id = 'site-id' AND claimed_by = 'user-id';
```

#### PHASE 3: Visit Execution Start
**Status**: `Accepted`
- Site shows with "Accepted" status in "My Visits"
- Ready to begin field visit
- **Action Button**: "Start Visit" (StartVisitButton)

**What Happens on Start**:
1. Captures GPS coordinates at start location
2. Sets `visit_started_by` = current user ID
3. Sets `visit_started_at` = current timestamp
4. Changes status to `In Progress`
5. Stores start GPS in `additional_data` JSONB field

**Database Updates**:
```sql
UPDATE mmp_site_entries SET
  visit_started_by = 'user-id',
  visit_started_at = NOW(),
  status = 'In Progress',
  additional_data = additional_data || '{"start_gps": {"lat": X, "lng": Y}}'::jsonb
WHERE id = 'site-id' AND accepted_by = 'user-id';
```

#### PHASE 4: Visit Completion
**Status**: `In Progress`
- Site shows with "In Progress" status
- Data collector performs site activities
- **Action Button**: "Complete Visit" (CompleteVisitButton)

**What Happens on Complete**:
1. Captures GPS coordinates at completion location
2. Sets `visit_completed_by` = current user ID
3. Sets `visit_completed_at` = current timestamp
4. Changes status to `Completed`
5. Stores end GPS in `additional_data` JSONB field
6. Stops GPS location tracking
7. Opens report submission form automatically

**Database Updates**:
```sql
UPDATE mmp_site_entries SET
  visit_completed_by = 'user-id',
  visit_completed_at = NOW(),
  status = 'Completed',
  additional_data = additional_data || '{"end_gps": {"lat": X, "lng": Y}}'::jsonb
WHERE id = 'site-id' AND visit_started_by = 'user-id';
```

#### PHASE 5: Cost Submission (Future Enhancement)
**Status**: `Completed`
- After report submission, show cost submission dialog
- Allow data collector to:
  - Review agreed enumerator fee
  - Review agreed transport fee
  - Add actual costs incurred (with receipts)
  - Submit for approval

#### PHASE 6: Payment Processing (Future Enhancement)
- Finance team reviews cost submissions
- Approves payment amounts
- Processes payment to data collector's wallet
- Updates payment status in system

## File Structure

### Core Service Layer
**File**: `lib/services/site_visit_service.dart`
- `getAvailableSiteVisits()` - Fetch Dispatched sites
- `getClaimedSiteVisits(userId)` - Fetch Assigned/Claimed sites
- `getAcceptedSiteVisits(userId)` - Fetch Accepted sites
- `getOngoingSiteVisits(userId)` - Fetch In Progress sites
- `getCompletedSiteVisits(userId)` - Fetch Completed sites
- `acceptVisit(siteId, userId)` - Accept assignment
- `startVisit(siteId)` - Start visit with GPS
- `completeVisit(siteId)` - Complete visit with GPS

### UI Components
**File**: `lib/screens/field_operations_enhanced_screen.dart`
- Main field operations screen
- `_loadVisits()` - Loads all visit stages
- `_handleVisitStatusChanged()` - Handles status transitions

**File**: `lib/screens/components/visit_details_sheet.dart`
- Bottom sheet with visit details
- Shows appropriate action buttons based on status
- Handles status-specific UI elements

### Action Buttons
**File**: `lib/widgets/claim_site_button.dart`
- Claim button for Dispatched sites
- Calls `claim_site_visit` RPC function
- Shows fee breakdown on success

**File**: `lib/widgets/accept_assignment_button.dart`
- Accept button for Assigned/Claimed sites
- Shows cost acknowledgment dialog
- Confirms enumerator and transport fees

**File**: `lib/widgets/start_visit_button.dart`
- Start button for Accepted sites
- Captures GPS at start
- Begins visit tracking

**File**: `lib/widgets/complete_visit_button.dart`
- Complete button for In Progress visits
- Captures GPS at completion
- Opens report form automatically

## Database Schema

### Table: `mmp_site_entries`

**Claim-related fields**:
- `claimed_by` (uuid) - User who claimed the site
- `claimed_at` (timestamptz) - When site was claimed

**Accept-related fields**:
- `accepted_by` (uuid) - User who accepted the assignment
- `accepted_at` (timestamptz) - When assignment was accepted

**Visit execution fields**:
- `visit_started_by` (uuid) - User who started the visit
- `visit_started_at` (timestamptz) - When visit started
- `visit_completed_by` (uuid) - User who completed the visit
- `visit_completed_at` (timestamptz) - When visit completed

**Cost fields**:
- `enumerator_fee` (numeric) - Data collector fee
- `transport_fee` (numeric) - Transport allowance
- `cost` (numeric) - Total payout (enumerator + transport)

**Status field**:
- `status` (text) - Current status: `Dispatched`, `Assigned`, `Accepted`, `In Progress`, `Completed`

**GPS tracking**:
- `additional_data` (jsonb) - Stores start/end GPS coordinates

## Required RPC Functions

### `claim_site_visit`
```sql
CREATE OR REPLACE FUNCTION claim_site_visit(
  p_site_id UUID,
  p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Atomic update with race condition protection
  UPDATE mmp_site_entries
  SET 
    claimed_by = p_user_id,
    claimed_at = NOW(),
    status = 'Assigned',
    enumerator_fee = (SELECT enumerator_fee FROM user_classifications WHERE user_id = p_user_id),
    transport_fee = (SELECT transport_fee FROM user_classifications WHERE user_id = p_user_id),
    cost = enumerator_fee + transport_fee
  WHERE id = p_site_id 
    AND status = 'Dispatched'
    AND claimed_by IS NULL
  RETURNING jsonb_build_object(
    'success', true,
    'site_id', id,
    'site_name', site_name,
    'enumerator_fee', enumerator_fee,
    'transport_fee', transport_fee,
    'total_payout', cost
  ) INTO v_result;
  
  IF v_result IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Site not available or already claimed'
    );
  END IF;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
```

## Testing Checklist

### Phase 1: Claiming
- [ ] Dispatched sites appear in "My Visits"
- [ ] "Claim Site" button visible for dispatched sites
- [ ] Clicking claim calls RPC function
- [ ] Race condition protection works (two users claiming same site)
- [ ] Status changes to "Assigned" after claim
- [ ] Fee breakdown shown in success message
- [ ] Claimed site shows in user's assigned list

### Phase 2: Accepting
- [ ] Assigned sites show "Accept Assignment" button
- [ ] Cost acknowledgment dialog displays correct fees
- [ ] Time remaining warning shows for claimed sites
- [ ] Accept button updates accepted_by and accepted_at
- [ ] Status changes to "Accepted"
- [ ] GPS tracking starts after acceptance
- [ ] Accepted site shows "Start Visit" button

### Phase 3: Starting Visit
- [ ] "Start Visit" button visible for accepted sites
- [ ] GPS coordinates captured at start
- [ ] visit_started_by and visit_started_at set correctly
- [ ] Status changes to "In Progress"
- [ ] Start GPS stored in additional_data

### Phase 4: Completing Visit
- [ ] "Complete Visit" button visible for in-progress sites
- [ ] GPS coordinates captured at completion
- [ ] visit_completed_by and visit_completed_at set correctly
- [ ] Status changes to "Completed"
- [ ] End GPS stored in additional_data
- [ ] Report form opens automatically
- [ ] GPS tracking stops

### Offline Support
- [ ] All actions queue when offline
- [ ] Sync happens when connection restored
- [ ] No data loss during offline operations
- [ ] UI shows offline indicators

## Benefits of This Implementation

### 1. Clear Lifecycle Stages
Each phase has a distinct status and corresponding UI, making it easy to track progress.

### 2. Race Condition Protection
The `claim_site_visit` RPC function ensures only one user can claim a site, preventing conflicts.

### 3. Cost Transparency
Data collectors see and acknowledge costs before accepting assignments.

### 4. GPS Tracking
Automatic GPS capture at start and end provides proof of visit and location verification.

### 5. Audit Trail
Complete trail of who claimed, accepted, started, and completed each visit with timestamps.

### 6. Offline Resilience
All operations work offline and sync when connection is restored.

### 7. User Experience
Progressive workflow with clear action buttons at each stage reduces confusion.

## Future Enhancements

1. **Cost Submission Dialog**: Allow data collectors to submit actual costs after completion
2. **Receipt Upload**: Support uploading receipts for transport/other costs
3. **Payment Tracking**: Show payment status and history
4. **Auto-expiry**: Return unclaimed sites to pool after time limit
5. **Notifications**: Push notifications for new assignments and payments
6. **Analytics**: Dashboard showing completion rates, payment status, etc.
