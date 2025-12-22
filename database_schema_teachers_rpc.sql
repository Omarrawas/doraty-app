-- Function to get all teachers securely (bypassing RLS for public listing)
CREATE OR REPLACE FUNCTION get_all_teachers_public()
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  email TEXT,
  avatar_url TEXT,
  branch TEXT,
  bio TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id as user_id, 
    u.full_name as name, 
    u.email,
    u.avatar_url, 
    u.branch,
    u.bio
  FROM users u
  JOIN user_roles ur ON u.id = ur.user_id
  JOIN roles r ON ur.role_id = r.id
  WHERE r.name = 'teacher';
END;
$$;

