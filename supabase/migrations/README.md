# PACT Mobile - Supabase Migration Guide

## 📋 Migration Order & Status

Apply these migrations in the following order. Each migration is designed to be **idempotent** (safe to run multiple times).

### ✅ Step 1: User Profiles Enhancement
**File:** `20240116_enhanced_registration_fields.sql`

**What it does:**
- Adds registration fields to `profiles` table: `phone`, `employee_id`, `hub_id`, `state_id`, `status`
- Creates indexes for faster queries
- Adds documentation comments

**Required:** Yes (Foundation for user management)

**Status Check:**
```sql
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('phone', 'employee_id', 'hub_id', 'state_id', 'status');
```

---

### ✅ Step 2: Chat System Foundation
**File:** `20240115_chat_contacts_and_comprehensive_safety.sql`

**What it does:**
- Creates `chat_contacts` table for custom contact names
- Creates `comprehensive_safety_checklists` table (LEGACY - will be replaced)
- Sets up RLS policies for both tables

**Required:** Yes (If using chat features)

**Status Check:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN ('chat_contacts', 'comprehensive_safety_checklists');
```

**Note:** The `comprehensive_safety_checklists` table in this migration is LEGACY. Use the newer `comprehensive_monitoring_checklists` table from migration `20240119` instead.

---

### ✅ Step 3: Chat Functionality Fix
**File:** `20240117_fix_chat_participants.sql`

**What it does:**
- Creates `chat_messages` table
- Adds proper RLS policies for messaging
- Creates indexes for performance
- Ensures chat_contacts indexes exist

**Required:** Yes (If using chat features)

**Status Check:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'chat_messages';
```

---

### ✅ Step 4: Location Tracking
**File:** `20240118_create_location_logs_table.sql`

**What it does:**
- Creates `location_logs` table for GPS tracking
- References `site_visits` table (must exist first)
- Sets up RLS policies for location data
- Creates performance indexes

**Required:** Yes (For field operations tracking)

**Dependencies:** Requires `site_visits` table to exist

**Status Check:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'location_logs';
```

---

### ✅ Step 5: Reports & Photos
**File:** `20240118_create_reports_tables.sql`

**What it does:**
- Creates `reports` table for field operation reports
- Creates `report_photos` table for photo attachments
- References `site_visits` table
- Sets up RLS policies based on visit assignments

**Required:** Yes (For report submission feature)

**Dependencies:** Requires `site_visits` table to exist

**Status Check:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN ('reports', 'report_photos');
```

---

### ✅ Step 6: Equipment & Site Visits Enhancements
**File:** `20240118_update_equipment_and_visits_columns.sql`

**What it does:**
- Adds `user_id`, `last_modified`, `created_at` columns to `equipment` table
- Adds `last_modified` column to `site_visits` table
- Creates auto-update triggers for timestamps
- Sets up RLS policies for equipment

**Required:** Yes (If using equipment or site visits features)

**Dependencies:** Requires `equipment` and `site_visits` tables to exist

**Status Check:**
```sql
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'equipment' 
AND column_name IN ('user_id', 'last_modified', 'created_at');

SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'site_visits' 
AND column_name = 'last_modified';
```

---

### ✅ Step 7: Comprehensive Monitoring (NEW)
**File:** `20240119_comprehensive_monitoring_checklists.sql`

**What it does:**
- Creates `comprehensive_monitoring_checklists` table (REPLACES old comprehensive_safety_checklists)
- Supports 5 activity types: AM, DM, PDM, PHL, MDM
- Uses JSONB for flexible response storage
- Creates `monitoring_photos` storage bucket
- Sets up comprehensive RLS policies

**Required:** Yes (For comprehensive monitoring forms)

**Status Check:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'comprehensive_monitoring_checklists';

SELECT name 
FROM storage.buckets 
WHERE name = 'monitoring_photos';
```

---

## 🗂️ Table Dependencies Map

```
auth.users (Supabase built-in)
    │
    ├─> profiles (20240116)
    │
    ├─> site_visits (Pre-existing/Manual creation)
    │   │
    │   ├─> reports (20240118)
    │   │   └─> report_photos (20240118)
    │   │
    │   └─> location_logs (20240118)
    │
    ├─> equipment (Pre-existing, enhanced by 20240118)
    │
    ├─> chat_contacts (20240115)
    │   └─> chat_messages (20240117)
    │
    └─> comprehensive_monitoring_checklists (20240119)
```

---

## 🚀 Quick Setup - Run All Migrations

### Option 1: Supabase CLI (Recommended)
```bash
# Navigate to project directory
cd c:\temp\pact_mobile

# Apply all migrations in order
supabase db push

# Or apply individually
supabase migration up 20240116_enhanced_registration_fields
supabase migration up 20240115_chat_contacts_and_comprehensive_safety
supabase migration up 20240117_fix_chat_participants
supabase migration up 20240118_create_location_logs_table
supabase migration up 20240118_create_reports_tables
supabase migration up 20240118_update_equipment_and_visits_columns
supabase migration up 20240119_comprehensive_monitoring_checklists
```

### Option 2: Supabase Dashboard
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Run each migration file in order:
   1. `20240116_enhanced_registration_fields.sql`
   2. `20240115_chat_contacts_and_comprehensive_safety.sql`
   3. `20240117_fix_chat_participants.sql`
   4. `20240118_create_location_logs_table.sql`
   5. `20240118_create_reports_tables.sql`
   6. `20240118_update_equipment_and_visits_columns.sql`
   7. `20240119_comprehensive_monitoring_checklists.sql`

---

## ✅ Verification Script

Run this in your Supabase SQL Editor to check all tables:

```sql
-- Check all required tables exist
SELECT 
    'profiles' as table_name,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') as exists
UNION ALL
SELECT 'chat_contacts', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_contacts')
UNION ALL
SELECT 'chat_messages', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_messages')
UNION ALL
SELECT 'location_logs', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'location_logs')
UNION ALL
SELECT 'reports', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'reports')
UNION ALL
SELECT 'report_photos', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'report_photos')
UNION ALL
SELECT 'equipment', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'equipment')
UNION ALL
SELECT 'site_visits', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'site_visits')
UNION ALL
SELECT 'comprehensive_monitoring_checklists', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'comprehensive_monitoring_checklists');

-- Check storage buckets
SELECT name, public 
FROM storage.buckets 
WHERE name = 'monitoring_photos';
```

---

## 📦 Storage Buckets Required

| Bucket Name | Public | Purpose |
|-------------|--------|---------|
| `monitoring_photos` | false | Comprehensive monitoring form photos |

Create missing buckets in Supabase Dashboard → Storage

---

## ⚠️ Important Notes

### Pre-existing Tables Required:
These tables must exist in your Supabase before running migrations:

1. **`site_visits`** - Core table for field operations
2. **`equipment`** - Equipment tracking (will be enhanced by migration)
3. **`user_roles`** - For admin access control (optional but referenced in RLS)

### If `site_visits` Doesn't Exist:
Create it manually with:
```sql
CREATE TABLE site_visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assigned_to UUID REFERENCES auth.users(id),
    site_name TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE site_visits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their assigned visits"
    ON site_visits FOR SELECT
    USING (assigned_to = auth.uid());
```

### If `equipment` Doesn't Exist:
Create it manually with:
```sql
CREATE TABLE equipment (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'OK',
    is_checked_in BOOLEAN DEFAULT TRUE,
    next_maintenance TEXT
);

ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
```

---

## 🔧 In-App Verification

Use the DatabaseConstraintChecker in your Flutter app:

```dart
import 'package:pact_mobile/utils/database_constraint_checker.dart';

// In your settings screen or debug menu
final results = await DatabaseConstraintChecker.runAllChecks();

// All checks should return true
results.forEach((key, value) {
  print('$key: $value');
});
```

---

## 📝 Migration File Naming Convention

Format: `YYYYMMDD_description.sql`

- `YYYYMMDD` - Date of creation
- `description` - Short kebab-case description

Example: `20240119_comprehensive_monitoring_checklists.sql`

---

## 🗑️ Deprecated Files

These files are no longer needed and can be safely deleted:

- **`create_comprehensive_monitoring_table.sql`** - Replaced by `20240119_comprehensive_monitoring_checklists.sql`
  - Old schema had different field names
  - New migration matches the Flutter app implementation

---

## 🆘 Troubleshooting

### Error: "relation does not exist"
**Cause:** Dependent table not created yet  
**Solution:** Check dependencies map and create pre-requisite tables

### Error: "foreign key constraint"
**Cause:** Referenced table doesn't exist  
**Solution:** Create parent tables first (site_visits, auth.users)

### Error: "policy already exists"
**Cause:** Migration run multiple times  
**Solution:** Safe to ignore - migrations are idempotent

### Error: "column already exists"
**Cause:** Migration run multiple times  
**Solution:** Safe to ignore - uses `IF NOT EXISTS` checks

---

## 📊 Migration Status Dashboard

After running all migrations, you should have:

- ✅ 9 tables created/updated
- ✅ 1 storage bucket created
- ✅ 30+ RLS policies
- ✅ 15+ indexes
- ✅ 3 auto-update triggers
- ✅ Full documentation comments

---

## 🎯 Next Steps After Migration

1. Run verification script in Supabase
2. Run DatabaseConstraintChecker in Flutter app
3. Test each feature:
   - User registration
   - Chat messaging
   - Location tracking
   - Report submission
   - Equipment management
   - Comprehensive monitoring forms
4. Monitor logs for any RLS policy issues
5. Verify data is syncing properly

---

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify all pre-requisite tables exist
3. Check Supabase logs for detailed error messages
4. Use DatabaseConstraintChecker for systematic verification

---

**Last Updated:** January 19, 2024  
**Total Migrations:** 7  
**Status:** Production Ready ✅
