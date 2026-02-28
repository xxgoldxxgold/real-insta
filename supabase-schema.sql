-- ============================================
-- RealInsta Database Schema
-- Supabase (PostgreSQL)
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. profiles (extends auth.users)
-- ============================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  display_name TEXT,
  bio TEXT CHECK (char_length(bio) <= 160),
  avatar_url TEXT,
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 2. posts
-- ============================================
CREATE TABLE public.posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  caption TEXT CHECK (char_length(caption) <= 300),
  location_lat DOUBLE PRECISION,
  location_lng DOUBLE PRECISION,
  location_name TEXT,
  exif_data JSONB,
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_posts_user_id ON public.posts(user_id);
CREATE INDEX idx_posts_created_at ON public.posts(created_at DESC);

-- ============================================
-- 3. likes
-- ============================================
CREATE TABLE public.likes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, post_id)
);

CREATE INDEX idx_likes_post_id ON public.likes(post_id);
CREATE INDEX idx_likes_user_id ON public.likes(user_id);

-- ============================================
-- 4. comments
-- ============================================
CREATE TABLE public.comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 500),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_comments_post_id ON public.comments(post_id);

-- ============================================
-- 5. follows
-- ============================================
CREATE TABLE public.follows (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX idx_follows_follower ON public.follows(follower_id);
CREATE INDEX idx_follows_following ON public.follows(following_id);

-- ============================================
-- 6. blocks
-- ============================================
CREATE TABLE public.blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(blocker_id, blocked_id),
  CHECK (blocker_id != blocked_id)
);

CREATE INDEX idx_blocks_blocker ON public.blocks(blocker_id);

-- ============================================
-- 7. reports
-- ============================================
CREATE TABLE public.reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  reported_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'nudity', 'harassment', 'violence', 'other')),
  details TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 8. notifications
-- ============================================
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow')),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_notifications_user ON public.notifications(user_id, created_at DESC);

-- ============================================
-- 9. hashtags support
-- ============================================
CREATE TABLE public.hashtags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.post_hashtags (
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  hashtag_id UUID NOT NULL REFERENCES public.hashtags(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, hashtag_id)
);

CREATE INDEX idx_hashtags_name ON public.hashtags(name);

-- ============================================
-- 10. Utility functions
-- ============================================

-- Get post count for user
CREATE OR REPLACE FUNCTION public.get_post_count(uid UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER FROM public.posts WHERE user_id = uid;
$$ LANGUAGE sql STABLE;

-- Get follower count (only for self)
CREATE OR REPLACE FUNCTION public.get_follower_count(uid UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER FROM public.follows WHERE following_id = uid;
$$ LANGUAGE sql STABLE;

-- Get following count (only for self)
CREATE OR REPLACE FUNCTION public.get_following_count(uid UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER FROM public.follows WHERE follower_id = uid;
$$ LANGUAGE sql STABLE;

-- Extract and save hashtags from caption
CREATE OR REPLACE FUNCTION public.extract_hashtags()
RETURNS TRIGGER AS $$
DECLARE
  tag TEXT;
  tag_id UUID;
BEGIN
  -- Delete existing hashtags for this post (on update)
  DELETE FROM public.post_hashtags WHERE post_id = NEW.id;

  -- Extract hashtags from caption
  IF NEW.caption IS NOT NULL THEN
    FOR tag IN
      SELECT DISTINCT lower(matches[1])
      FROM regexp_matches(NEW.caption, '#([a-zA-Z0-9\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF_]+)', 'g') AS matches
    LOOP
      -- Insert hashtag if not exists
      INSERT INTO public.hashtags (name)
      VALUES (tag)
      ON CONFLICT (name) DO NOTHING;

      SELECT id INTO tag_id FROM public.hashtags WHERE name = tag;

      INSERT INTO public.post_hashtags (post_id, hashtag_id)
      VALUES (NEW.id, tag_id)
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_post_hashtags
  AFTER INSERT OR UPDATE OF caption ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.extract_hashtags();

-- Auto-create notifications
CREATE OR REPLACE FUNCTION public.create_notification()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_TABLE_NAME = 'likes' THEN
    INSERT INTO public.notifications (user_id, actor_id, type, post_id)
    SELECT p.user_id, NEW.user_id, 'like', NEW.post_id
    FROM public.posts p
    WHERE p.id = NEW.post_id AND p.user_id != NEW.user_id;
  ELSIF TG_TABLE_NAME = 'comments' THEN
    INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id)
    SELECT p.user_id, NEW.user_id, 'comment', NEW.post_id, NEW.id
    FROM public.posts p
    WHERE p.id = NEW.post_id AND p.user_id != NEW.user_id;
  ELSIF TG_TABLE_NAME = 'follows' THEN
    INSERT INTO public.notifications (user_id, actor_id, type)
    VALUES (NEW.following_id, NEW.follower_id, 'follow');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_like_notify AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.create_notification();

CREATE TRIGGER on_comment_notify AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.create_notification();

CREATE TRIGGER on_follow_notify AFTER INSERT ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.create_notification();

-- ============================================
-- 11. Row Level Security (RLS)
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_hashtags ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "Profiles: anyone can view" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Profiles: users can update own" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Posts: viewable if not blocked
CREATE POLICY "Posts: view non-blocked" ON public.posts FOR SELECT USING (
  NOT EXISTS (
    SELECT 1 FROM public.blocks
    WHERE (blocker_id = auth.uid() AND blocked_id = posts.user_id)
       OR (blocker_id = posts.user_id AND blocked_id = auth.uid())
  )
);
CREATE POLICY "Posts: auth users can insert" ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Posts: users can delete own" ON public.posts FOR DELETE USING (auth.uid() = user_id);

-- Likes
CREATE POLICY "Likes: anyone can view" ON public.likes FOR SELECT USING (true);
CREATE POLICY "Likes: auth users can insert" ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Likes: users can delete own" ON public.likes FOR DELETE USING (auth.uid() = user_id);

-- Comments
CREATE POLICY "Comments: anyone can view" ON public.comments FOR SELECT USING (true);
CREATE POLICY "Comments: auth users can insert" ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Comments: owner or post owner can delete" ON public.comments FOR DELETE USING (
  auth.uid() = user_id OR
  auth.uid() IN (SELECT user_id FROM public.posts WHERE id = comments.post_id)
);

-- Follows
CREATE POLICY "Follows: anyone can view" ON public.follows FOR SELECT USING (true);
CREATE POLICY "Follows: auth users can insert" ON public.follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Follows: users can delete own" ON public.follows FOR DELETE USING (auth.uid() = follower_id);

-- Blocks
CREATE POLICY "Blocks: users can view own" ON public.blocks FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "Blocks: auth users can insert" ON public.blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Blocks: users can delete own" ON public.blocks FOR DELETE USING (auth.uid() = blocker_id);

-- Reports
CREATE POLICY "Reports: auth users can insert" ON public.reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- Notifications
CREATE POLICY "Notifications: users can view own" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Notifications: users can update own" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Notifications: system can insert" ON public.notifications FOR INSERT WITH CHECK (true);

-- Hashtags (public read)
CREATE POLICY "Hashtags: anyone can view" ON public.hashtags FOR SELECT USING (true);
CREATE POLICY "Hashtags: system can insert" ON public.hashtags FOR INSERT WITH CHECK (true);

-- Post hashtags (public read)
CREATE POLICY "Post hashtags: anyone can view" ON public.post_hashtags FOR SELECT USING (true);
CREATE POLICY "Post hashtags: system can manage" ON public.post_hashtags FOR INSERT WITH CHECK (true);
CREATE POLICY "Post hashtags: system can delete" ON public.post_hashtags FOR DELETE USING (true);

-- ============================================
-- 12. Storage bucket for photos
-- ============================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('posts', 'posts', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "Posts images: anyone can view" ON storage.objects FOR SELECT USING (bucket_id = 'posts');
CREATE POLICY "Posts images: auth users can upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'posts' AND auth.role() = 'authenticated');
CREATE POLICY "Posts images: users can delete own" ON storage.objects FOR DELETE USING (bucket_id = 'posts' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Avatars: anyone can view" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Avatars: auth users can upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');
CREATE POLICY "Avatars: users can delete own" ON storage.objects FOR DELETE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
