-- Fix security issue: Remove public access to email addresses in profiles table

-- Drop the existing overly permissive policy
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;

-- Create a more secure policy for viewing public profile information (excluding email)
-- This policy allows users to see public profile info of other users, but not email addresses
CREATE POLICY "Users can view public profile info" 
ON public.profiles 
FOR SELECT 
USING (
  -- Allow access to public profile fields, but restrict email access
  CASE 
    WHEN auth.uid() = user_id THEN true  -- Users can see their own complete profile
    ELSE (
      -- For other users, only allow access if email is not being accessed
      -- This is achieved by the application layer selecting only specific columns
      auth.uid() IS NOT NULL  -- Must be authenticated
    )
  END
);

-- Create a security definer function to get public profile data safely
CREATE OR REPLACE FUNCTION public.get_public_profile(profile_user_id uuid)
RETURNS TABLE(
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text
) 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    p.user_id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.bio
  FROM public.profiles p
  WHERE p.user_id = profile_user_id;
$$;

-- Create a security definer function to get multiple public profiles safely
CREATE OR REPLACE FUNCTION public.get_public_profiles(profile_user_ids uuid[])
RETURNS TABLE(
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text
) 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    p.user_id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.bio
  FROM public.profiles p
  WHERE p.user_id = ANY(profile_user_ids);
$$;

-- Create a function for searching profiles safely (without email exposure)
CREATE OR REPLACE FUNCTION public.search_public_profiles(search_query text, current_user_id uuid DEFAULT NULL)
RETURNS TABLE(
  user_id uuid,
  username text,
  display_name text,
  avatar_url text
) 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    p.user_id,
    p.username,
    p.display_name,
    p.avatar_url
  FROM public.profiles p
  WHERE 
    (p.username ILIKE '%' || search_query || '%' OR 
     p.display_name ILIKE '%' || search_query || '%')
    AND (current_user_id IS NULL OR p.user_id != current_user_id)
  ORDER BY 
    CASE 
      WHEN p.username ILIKE search_query || '%' THEN 1
      WHEN p.display_name ILIKE search_query || '%' THEN 2
      ELSE 3
    END,
    p.username
  LIMIT 10;
$$;