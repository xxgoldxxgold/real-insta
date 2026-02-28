-- ============================================
-- RealInsta Database Schema (ri_ prefix)
-- gc2.jp Supabase プロジェクト内に追加
-- ============================================

-- ============================================
-- 1. ri_profiles (real-insta用プロフィール)
-- ============================================
CREATE TABLE public.ri_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  display_name TEXT,
  bio TEXT CHECK (char_length(bio) <= 160),
  avatar_url TEXT,
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- サインアップ時にri_profilesも自動作成
CREATE OR REPLACE FUNCTION public.handle_new_user_ri()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.ri_profiles (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created_ri
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_ri();

-- 既存ユーザーのri_profilesを作成
INSERT INTO public.ri_profiles (id, display_name, avatar_url)
SELECT id,
  COALESCE(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', ''),
  COALESCE(raw_user_meta_data->>'avatar_url', raw_user_meta_data->>'picture', '')
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 2. ri_posts
-- ============================================
CREATE TABLE public.ri_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  caption TEXT CHECK (char_length(caption) <= 300),
  location_lat DOUBLE PRECISION,
  location_lng DOUBLE PRECISION,
  location_name TEXT,
  exif_data JSONB,
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ri_posts_user_id ON public.ri_posts(user_id);
CREATE INDEX idx_ri_posts_created_at ON public.ri_posts(created_at DESC);

-- ============================================
-- 3. ri_likes
-- ============================================
CREATE TABLE public.ri_likes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES public.ri_posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, post_id)
);

CREATE INDEX idx_ri_likes_post_id ON public.ri_likes(post_id);
CREATE INDEX idx_ri_likes_user_id ON public.ri_likes(user_id);

-- ============================================
-- 4. ri_comments
-- ============================================
CREATE TABLE public.ri_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES public.ri_posts(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 500),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ri_comments_post_id ON public.ri_comments(post_id);

-- ============================================
-- 5. ri_follows
-- ============================================
CREATE TABLE public.ri_follows (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX idx_ri_follows_follower ON public.ri_follows(follower_id);
CREATE INDEX idx_ri_follows_following ON public.ri_follows(following_id);

-- ============================================
-- 6. ri_blocks
-- ============================================
CREATE TABLE public.ri_blocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  blocker_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(blocker_id, blocked_id),
  CHECK (blocker_id != blocked_id)
);

CREATE INDEX idx_ri_blocks_blocker ON public.ri_blocks(blocker_id);

-- ============================================
-- 7. ri_reports
-- ============================================
CREATE TABLE public.ri_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.ri_posts(id) ON DELETE CASCADE,
  reported_user_id UUID REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'nudity', 'harassment', 'violence', 'other')),
  details TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 8. ri_notifications
-- ============================================
CREATE TABLE public.ri_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow')),
  post_id UUID REFERENCES public.ri_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.ri_comments(id) ON DELETE CASCADE,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ri_notifications_user ON public.ri_notifications(user_id, created_at DESC);

-- ============================================
-- 9. ri_hashtags
-- ============================================
CREATE TABLE public.ri_hashtags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.ri_post_hashtags (
  post_id UUID NOT NULL REFERENCES public.ri_posts(id) ON DELETE CASCADE,
  hashtag_id UUID NOT NULL REFERENCES public.ri_hashtags(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, hashtag_id)
);

CREATE INDEX idx_ri_hashtags_name ON public.ri_hashtags(name);

-- ============================================
-- 10. トリガー関数
-- ============================================

-- ハッシュタグ抽出
CREATE OR REPLACE FUNCTION public.ri_extract_hashtags()
RETURNS TRIGGER AS $$
DECLARE
  tag TEXT;
  tag_id UUID;
BEGIN
  DELETE FROM public.ri_post_hashtags WHERE post_id = NEW.id;
  IF NEW.caption IS NOT NULL THEN
    FOR tag IN
      SELECT DISTINCT lower(matches[1])
      FROM regexp_matches(NEW.caption, '#([a-zA-Z0-9\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF_]+)', 'g') AS matches
    LOOP
      INSERT INTO public.ri_hashtags (name) VALUES (tag) ON CONFLICT (name) DO NOTHING;
      SELECT id INTO tag_id FROM public.ri_hashtags WHERE name = tag;
      INSERT INTO public.ri_post_hashtags (post_id, hashtag_id) VALUES (NEW.id, tag_id) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_ri_post_hashtags
  AFTER INSERT OR UPDATE OF caption ON public.ri_posts
  FOR EACH ROW EXECUTE FUNCTION public.ri_extract_hashtags();

-- 通知自動作成
CREATE OR REPLACE FUNCTION public.ri_create_notification()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_TABLE_NAME = 'ri_likes' THEN
    INSERT INTO public.ri_notifications (user_id, actor_id, type, post_id)
    SELECT p.user_id, NEW.user_id, 'like', NEW.post_id
    FROM public.ri_posts p WHERE p.id = NEW.post_id AND p.user_id != NEW.user_id;
  ELSIF TG_TABLE_NAME = 'ri_comments' THEN
    INSERT INTO public.ri_notifications (user_id, actor_id, type, post_id, comment_id)
    SELECT p.user_id, NEW.user_id, 'comment', NEW.post_id, NEW.id
    FROM public.ri_posts p WHERE p.id = NEW.post_id AND p.user_id != NEW.user_id;
  ELSIF TG_TABLE_NAME = 'ri_follows' THEN
    INSERT INTO public.ri_notifications (user_id, actor_id, type)
    VALUES (NEW.following_id, NEW.follower_id, 'follow');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_ri_like_notify AFTER INSERT ON public.ri_likes
  FOR EACH ROW EXECUTE FUNCTION public.ri_create_notification();
CREATE TRIGGER on_ri_comment_notify AFTER INSERT ON public.ri_comments
  FOR EACH ROW EXECUTE FUNCTION public.ri_create_notification();
CREATE TRIGGER on_ri_follow_notify AFTER INSERT ON public.ri_follows
  FOR EACH ROW EXECUTE FUNCTION public.ri_create_notification();

-- ============================================
-- 11. RLS
-- ============================================
ALTER TABLE public.ri_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_post_hashtags ENABLE ROW LEVEL SECURITY;

-- ri_profiles
CREATE POLICY "ri_profiles: anyone can view" ON public.ri_profiles FOR SELECT USING (true);
CREATE POLICY "ri_profiles: users can update own" ON public.ri_profiles FOR UPDATE USING (auth.uid() = id);

-- ri_posts
CREATE POLICY "ri_posts: view non-blocked" ON public.ri_posts FOR SELECT USING (
  NOT EXISTS (SELECT 1 FROM public.ri_blocks WHERE (blocker_id = auth.uid() AND blocked_id = ri_posts.user_id) OR (blocker_id = ri_posts.user_id AND blocked_id = auth.uid()))
);
CREATE POLICY "ri_posts: auth users can insert" ON public.ri_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ri_posts: users can delete own" ON public.ri_posts FOR DELETE USING (auth.uid() = user_id);

-- ri_likes
CREATE POLICY "ri_likes: anyone can view" ON public.ri_likes FOR SELECT USING (true);
CREATE POLICY "ri_likes: auth users can insert" ON public.ri_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ri_likes: users can delete own" ON public.ri_likes FOR DELETE USING (auth.uid() = user_id);

-- ri_comments
CREATE POLICY "ri_comments: anyone can view" ON public.ri_comments FOR SELECT USING (true);
CREATE POLICY "ri_comments: auth users can insert" ON public.ri_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ri_comments: owner or post owner can delete" ON public.ri_comments FOR DELETE USING (
  auth.uid() = user_id OR auth.uid() IN (SELECT user_id FROM public.ri_posts WHERE id = ri_comments.post_id)
);

-- ri_follows
CREATE POLICY "ri_follows: anyone can view" ON public.ri_follows FOR SELECT USING (true);
CREATE POLICY "ri_follows: auth users can insert" ON public.ri_follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "ri_follows: users can delete own" ON public.ri_follows FOR DELETE USING (auth.uid() = follower_id);

-- ri_blocks
CREATE POLICY "ri_blocks: users can view own" ON public.ri_blocks FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "ri_blocks: auth users can insert" ON public.ri_blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "ri_blocks: users can delete own" ON public.ri_blocks FOR DELETE USING (auth.uid() = blocker_id);

-- ri_reports
CREATE POLICY "ri_reports: auth users can insert" ON public.ri_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- ri_notifications
CREATE POLICY "ri_notifications: users can view own" ON public.ri_notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "ri_notifications: users can update own" ON public.ri_notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "ri_notifications: system can insert" ON public.ri_notifications FOR INSERT WITH CHECK (true);

-- ri_hashtags
CREATE POLICY "ri_hashtags: anyone can view" ON public.ri_hashtags FOR SELECT USING (true);
CREATE POLICY "ri_hashtags: system can insert" ON public.ri_hashtags FOR INSERT WITH CHECK (true);

-- ri_post_hashtags
CREATE POLICY "ri_post_hashtags: anyone can view" ON public.ri_post_hashtags FOR SELECT USING (true);
CREATE POLICY "ri_post_hashtags: system can manage" ON public.ri_post_hashtags FOR INSERT WITH CHECK (true);
CREATE POLICY "ri_post_hashtags: system can delete" ON public.ri_post_hashtags FOR DELETE USING (true);

-- ============================================
-- 12. Storage バケット (ri- prefix)
-- ============================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('ri-posts', 'ri-posts', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('ri-avatars', 'ri-avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Storage ポリシー
CREATE POLICY "ri-posts: anyone can view" ON storage.objects FOR SELECT USING (bucket_id = 'ri-posts');
CREATE POLICY "ri-posts: auth users can upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'ri-posts' AND auth.role() = 'authenticated');
CREATE POLICY "ri-posts: users can delete own" ON storage.objects FOR DELETE USING (bucket_id = 'ri-posts' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "ri-avatars: anyone can view" ON storage.objects FOR SELECT USING (bucket_id = 'ri-avatars');
CREATE POLICY "ri-avatars: auth users can upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'ri-avatars' AND auth.role() = 'authenticated');
CREATE POLICY "ri-avatars: users can delete own" ON storage.objects FOR DELETE USING (bucket_id = 'ri-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================
-- 13. ri_conversations (DM会話)
-- ============================================
CREATE TABLE public.ri_conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  last_message_text TEXT,
  last_message_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  CHECK (user1_id < user2_id),
  UNIQUE(user1_id, user2_id)
);

CREATE INDEX idx_ri_conversations_user1 ON public.ri_conversations(user1_id);
CREATE INDEX idx_ri_conversations_user2 ON public.ri_conversations(user2_id);
CREATE INDEX idx_ri_conversations_last ON public.ri_conversations(last_message_at DESC);

-- ============================================
-- 14. ri_messages (DMメッセージ)
-- ============================================
CREATE TABLE public.ri_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES public.ri_conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.ri_profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 1000),
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ri_messages_conv ON public.ri_messages(conversation_id, created_at DESC);
CREATE INDEX idx_ri_messages_unread ON public.ri_messages(conversation_id, is_read) WHERE is_read = false;

-- メッセージINSERT時にri_conversationsのlast_message更新
CREATE OR REPLACE FUNCTION public.ri_update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.ri_conversations
  SET last_message_text = NEW.content,
      last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_ri_message_insert
  AFTER INSERT ON public.ri_messages
  FOR EACH ROW EXECUTE FUNCTION public.ri_update_conversation_last_message();

-- RLS
ALTER TABLE public.ri_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ri_messages ENABLE ROW LEVEL SECURITY;

-- ri_conversations: 参加者のみ閲覧
CREATE POLICY "ri_conversations: participants can view" ON public.ri_conversations
  FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- ri_conversations: ブロック中でなければ作成可能
CREATE POLICY "ri_conversations: create if not blocked" ON public.ri_conversations
  FOR INSERT WITH CHECK (
    (auth.uid() = user1_id OR auth.uid() = user2_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.ri_blocks
      WHERE (blocker_id = user1_id AND blocked_id = user2_id)
         OR (blocker_id = user2_id AND blocked_id = user1_id)
    )
  );

-- ri_messages: 会話参加者のみ閲覧
CREATE POLICY "ri_messages: participants can view" ON public.ri_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.ri_conversations c
      WHERE c.id = ri_messages.conversation_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

-- ri_messages: 送信者のみ挿入（会話参加者であること）
CREATE POLICY "ri_messages: sender can insert" ON public.ri_messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.ri_conversations c
      WHERE c.id = ri_messages.conversation_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.ri_conversations c
      JOIN public.ri_blocks b ON (
        (b.blocker_id = c.user1_id AND b.blocked_id = c.user2_id)
        OR (b.blocker_id = c.user2_id AND b.blocked_id = c.user1_id)
      )
      WHERE c.id = ri_messages.conversation_id
    )
  );

-- ri_messages: 受信者のみ既読更新
CREATE POLICY "ri_messages: receiver can mark read" ON public.ri_messages
  FOR UPDATE USING (
    auth.uid() != sender_id
    AND EXISTS (
      SELECT 1 FROM public.ri_conversations c
      WHERE c.id = ri_messages.conversation_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

-- Realtime: ri_messagesをpublicationに追加
ALTER PUBLICATION supabase_realtime ADD TABLE public.ri_messages;
