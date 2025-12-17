-- Migration: Create classification system and fee structures
-- Description: Enables dynamic enumerator fee calculation based on data collector classification
-- Date: 2025-11-23

BEGIN;

-- Create enum types for classification
CREATE TYPE IF NOT EXISTS classification_level AS ENUM ('junior', 'intermediate', 'senior', 'lead');
CREATE TYPE IF NOT EXISTS classification_role_scope AS ENUM ('field_officer', 'team_leader', 'supervisor', 'coordinator');

-- Create user_classifications table
CREATE TABLE IF NOT EXISTS public.user_classifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  classification_level classification_level NOT NULL,
  role_scope classification_role_scope NOT NULL,
  is_active BOOLEAN DEFAULT true,
  effective_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  effective_until TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id),
  notes TEXT
);

-- Create classification_fee_structures table
CREATE TABLE IF NOT EXISTS public.classification_fee_structures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  classification_level classification_level NOT NULL,
  role_scope classification_role_scope NOT NULL,
  site_visit_base_fee_cents INTEGER NOT NULL COMMENT 'Base fee in SDG (not cents, despite the name)',
  complexity_multiplier NUMERIC(4,2) DEFAULT 1.0,
  is_active BOOLEAN DEFAULT true,
  valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  valid_until TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  notes TEXT,
  UNIQUE(classification_level, role_scope, valid_from)
);

-- Insert default fee structures
INSERT INTO classification_fee_structures (classification_level, role_scope, site_visit_base_fee_cents, complexity_multiplier, notes)
VALUES
  ('junior', 'field_officer', 50, 1.0, 'Junior Field Officer base fee'),
  ('junior', 'team_leader', 75, 1.2, 'Junior Team Leader with multiplier'),
  ('intermediate', 'field_officer', 75, 1.0, 'Intermediate Field Officer'),
  ('intermediate', 'team_leader', 100, 1.3, 'Intermediate Team Leader'),
  ('intermediate', 'supervisor', 125, 1.5, 'Intermediate Supervisor'),
  ('senior', 'field_officer', 100, 1.0, 'Senior Field Officer'),
  ('senior', 'team_leader', 150, 1.4, 'Senior Team Leader'),
  ('senior', 'supervisor', 175, 1.6, 'Senior Supervisor'),
  ('lead', 'coordinator', 200, 1.8, 'Lead Coordinator highest tier')
ON CONFLICT DO NOTHING;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_classifications_user_id ON public.user_classifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_classifications_is_active ON public.user_classifications(is_active);
CREATE INDEX IF NOT EXISTS idx_user_classifications_effective_from ON public.user_classifications(effective_from);
CREATE INDEX IF NOT EXISTS idx_classification_fee_structures_level_scope ON public.classification_fee_structures(classification_level, role_scope);
CREATE INDEX IF NOT EXISTS idx_classification_fee_structures_is_active ON public.classification_fee_structures(is_active);

-- Enable RLS
ALTER TABLE public.user_classifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classification_fee_structures ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for user_classifications
CREATE POLICY "Users can view their own classification"
  ON public.user_classifications
  FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'authenticated');

CREATE POLICY "Admins can manage classifications"
  ON public.user_classifications
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'supervisor')
    )
  );

-- Create RLS policies for classification_fee_structures (read-only for collectors)
CREATE POLICY "Everyone can read fee structures"
  ON public.classification_fee_structures
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Only admins can modify fee structures"
  ON public.classification_fee_structures
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'supervisor')
    )
  );

-- Add comments
COMMENT ON TABLE public.user_classifications IS 'Tracks data collector classifications and their effective periods';
COMMENT ON TABLE public.classification_fee_structures IS 'Defines base fees and multipliers for each classification+role combination';
COMMENT ON COLUMN public.classification_fee_structures.site_visit_base_fee_cents IS 'Base fee amount in SDG currency units';
COMMENT ON COLUMN public.classification_fee_structures.complexity_multiplier IS 'Multiplier applied to base fee for complex sites (0.5-2.0)';

COMMIT;
