# Migration Cleanup Instructions

## Files to DELETE (Deprecated/Duplicate)

### ❌ Delete This File:
- **`create_comprehensive_monitoring_table.sql`**
  - **Reason:** Replaced by `20240119_comprehensive_monitoring_checklists.sql`
  - **Issue:** Different schema (used TEXT for id, wrong field names)
  - **Replacement:** Use the dated migration instead

## Files UPDATED (Fixed Issues)

### ✅ Updated Files:
1. **`20240118_create_reports_tables.sql`**
   - Fixed: Changed `field_visits` → `site_visits` (correct table name)
   
2. **`20240117_fix_chat_participants.sql`**
   - Fixed: Added missing chat_messages table and RLS policies
   - Was: Empty file
   
3. **`20240119_comprehensive_monitoring_checklists.sql`**
   - Fixed: Created proper schema matching Flutter app
   - Replaced: Old `create_comprehensive_monitoring_table.sql`

## How to Clean Up

### Option 1: PowerShell Command
```powershell
# Navigate to migrations folder
cd c:\temp\pact_mobile\supabase\migrations

# Delete the deprecated file
Remove-Item -Path "create_comprehensive_monitoring_table.sql"

# Verify it's gone
Get-ChildItem
```

### Option 2: Manual Deletion
1. Open File Explorer
2. Navigate to: `c:\temp\pact_mobile\supabase\migrations\`
3. Delete: `create_comprehensive_monitoring_table.sql`

## Final Migration File List

After cleanup, you should have these 7 files:

```
supabase/migrations/
├── 20240115_chat_contacts_and_comprehensive_safety.sql  ✅
├── 20240116_enhanced_registration_fields.sql             ✅
├── 20240117_fix_chat_participants.sql                    ✅ (Updated)
├── 20240118_create_location_logs_table.sql               ✅
├── 20240118_create_reports_tables.sql                    ✅ (Updated)
├── 20240118_update_equipment_and_visits_columns.sql      ✅
├── 20240119_comprehensive_monitoring_checklists.sql      ✅ (New)
└── README.md                                             📝 (Documentation)
```

## Verification

Run this command to see your clean migration folder:
```powershell
cd c:\temp\pact_mobile\supabase\migrations
Get-ChildItem | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
```

Expected output: 8 files (7 .sql + 1 README.md)

## Database Status

If you already ran `create_comprehensive_monitoring_table.sql`:

### Option A: Table Already Exists With OLD Schema
Run this to drop and recreate with correct schema:
```sql
-- ⚠️ WARNING: This will delete existing data!
DROP TABLE IF EXISTS comprehensive_monitoring_checklists CASCADE;

-- Then run the new migration:
-- 20240119_comprehensive_monitoring_checklists.sql
```

### Option B: Keep Existing Data (Migrate Schema)
Run this to update existing table to new schema:
```sql
-- Add missing columns
ALTER TABLE comprehensive_monitoring_checklists
ADD COLUMN IF NOT EXISTS enumerator_phone TEXT,
ADD COLUMN IF NOT EXISTS gps_coordinates TEXT,
ADD COLUMN IF NOT EXISTS district TEXT,
ADD COLUMN IF NOT EXISTS sub_county TEXT,
ADD COLUMN IF NOT EXISTS parish TEXT,
ADD COLUMN IF NOT EXISTS village TEXT,
ADD COLUMN IF NOT EXISTS site_code TEXT,
ADD COLUMN IF NOT EXISTS activity_am BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS activity_dm BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS activity_pdm BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS activity_phl BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS activity_mdm BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS am_responses JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS dm_responses JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS pdm_responses JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS phl_responses JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS mdm_responses JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS photo_urls TEXT[] DEFAULT '{}';

-- Change id from TEXT to UUID if needed
-- ⚠️ This is complex - recommend Option A (drop and recreate) instead
```

---

**Recommendation:** Use **Option A** (drop and recreate) unless you have production data you need to preserve.
