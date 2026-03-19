-- Table to store bundle information
CREATE TABLE IF NOT EXISTS bundles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    price NUMERIC NOT NULL,
    discount_percentage INTEGER DEFAULT 0,
    currency TEXT DEFAULT 'ل.س',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Junction table to associate courses with bundles
CREATE TABLE IF NOT EXISTS bundle_courses (
    bundle_id UUID REFERENCES bundles(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    PRIMARY KEY (bundle_id, course_id)
);

-- Enable Row Level Security (RLS)
ALTER TABLE bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE bundle_courses ENABLE ROW LEVEL SECURITY;

-- Policies for public viewing (if applicable)
-- Assuming anyone can view bundles
CREATE POLICY "Public bundles are viewable by everyone" ON bundles
    FOR SELECT USING (true);

CREATE POLICY "Public bundle courses are viewable by everyone" ON bundle_courses
    FOR SELECT USING (true);

-- Admin policies (assuming admin has full access)
-- Note: Replace 'authenticated' with appropriate role or check if current user is admin
CREATE POLICY "Admins can insert bundles" ON bundles
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Admins can update bundles" ON bundles
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can delete bundles" ON bundles
    FOR DELETE USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage bundle_courses" ON bundle_courses
    FOR ALL USING (auth.role() = 'authenticated');
