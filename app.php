<?php
// real-insta メインアプリ（認証後）
?>
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Real Insta</title>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: #fafafa;
  min-height: 100vh;
}
.header {
  background: #fff;
  border-bottom: 1px solid #dbdbdb;
  padding: 12px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  position: sticky;
  top: 0;
  z-index: 100;
}
.header-logo {
  font-size: 20px;
  font-weight: 700;
  color: #262626;
}
.header-right {
  display: flex;
  align-items: center;
  gap: 12px;
}
.user-info {
  font-size: 13px;
  color: #8e8e8e;
}
.btn-logout {
  padding: 6px 14px;
  border: 1px solid #dbdbdb;
  border-radius: 6px;
  background: #fff;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  color: #262626;
}
.btn-logout:hover { background: #fafafa; }
.main {
  max-width: 600px;
  margin: 40px auto;
  padding: 20px;
  text-align: center;
  color: #8e8e8e;
}
</style>
</head>
<body>

<div class="header">
  <div class="header-logo">Real Insta</div>
  <div class="header-right">
    <span class="user-info" id="userInfo"></span>
    <button class="btn-logout" onclick="logout()">ログアウト</button>
  </div>
</div>

<div class="main">
  <p>ログイン成功！アプリはこれから構築していきます。</p>
</div>

<script>
const SUPABASE_URL = 'https://vylwpbbwkmuxrfzmgvkj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ5bHdwYmJ3a211eHJmem1ndmtqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkwMzE5MDgsImV4cCI6MjA3NDYwNzkwOH0.oDxf3R0X-PWLp5ZP4ERu9Co7GehAwxYLORY9bF8zeBw';

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function init() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    window.location.href = '/';
    return;
  }
  const user = session.user;
  const name = user.user_metadata?.full_name || user.user_metadata?.name || user.email;
  document.getElementById('userInfo').textContent = name;
}

async function logout() {
  await supabase.auth.signOut();
  window.location.href = '/';
}

init();
</script>
</body>
</html>
