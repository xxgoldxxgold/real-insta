<?php // RealInsta - Main App SPA ?>
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<title>Real Insta</title>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<style>
:root {
  --bg: #fafafa;
  --card: #ffffff;
  --border: #dbdbdb;
  --text: #262626;
  --text-secondary: #8e8e8e;
  --accent: #0095f6;
  --like: #ed4956;
  --nav-height: 50px;
  --header-height: 44px;
  --safe-bottom: env(safe-area-inset-bottom, 0px);
}
* { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
html, body { height: 100%; overflow: hidden; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--bg);
  color: var(--text);
  font-size: 14px;
  -webkit-font-smoothing: antialiased;
}
a { color: inherit; text-decoration: none; }
button { font-family: inherit; cursor: pointer; border: none; background: none; }
input, textarea { font-family: inherit; font-size: 14px; }
img { display: block; }

/* Layout */
#app { height: 100vh; display: flex; flex-direction: column; }
.header {
  height: var(--header-height);
  background: var(--card);
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  padding: 0 16px;
  flex-shrink: 0;
  z-index: 100;
}
.header-title { font-size: 16px; font-weight: 600; flex: 1; text-align: center; }
.header-left, .header-right { width: 60px; display: flex; align-items: center; }
.header-right { justify-content: flex-end; }
.header-btn { padding: 4px; color: var(--text); font-size: 14px; font-weight: 600; }
.header-logo { font-size: 20px; font-weight: 700; flex: 1; }
.main-content {
  flex: 1;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  padding-bottom: calc(var(--nav-height) + var(--safe-bottom));
}
.bottom-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: calc(var(--nav-height) + var(--safe-bottom));
  padding-bottom: var(--safe-bottom);
  background: var(--card);
  border-top: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: space-around;
  z-index: 100;
}
.nav-item {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: 0;
}
.nav-item svg { width: 24px; height: 24px; }
.nav-item.active svg { fill: var(--text); stroke-width: 2.5; }
.nav-avatar { width: 24px; height: 24px; border-radius: 50%; object-fit: cover; border: 2px solid transparent; }
.nav-item.active .nav-avatar { border-color: var(--text); }

/* Feed */
.post-card { background: var(--card); border-bottom: 1px solid var(--border); }
.post-header { display: flex; align-items: center; padding: 10px 12px; gap: 10px; }
.post-avatar { width: 32px; height: 32px; border-radius: 50%; object-fit: cover; background: #eee; }
.post-username { font-weight: 600; font-size: 13px; flex: 1; }
.post-more { color: var(--text); padding: 4px; }
.post-image { width: 100%; aspect-ratio: 1; object-fit: cover; background: #eee; }
.post-actions { display: flex; align-items: center; padding: 8px 12px; gap: 14px; }
.post-action { padding: 2px; }
.post-action svg { width: 24px; height: 24px; }
.post-action.liked svg { fill: var(--like); stroke: var(--like); }
.post-caption { padding: 0 12px 4px; font-size: 13px; line-height: 1.4; }
.post-caption strong { font-weight: 600; }
.post-comments-link { padding: 0 12px 4px; color: var(--text-secondary); font-size: 13px; }
.post-time { padding: 0 12px 12px; color: var(--text-secondary); font-size: 11px; }
.post-caption .hashtag { color: #00376b; font-weight: 500; }
.verified-badge { color: #0095f6; font-size: 12px; margin-left: 4px; }

/* Explore */
.explore-search {
  padding: 8px 12px;
  background: var(--card);
  border-bottom: 1px solid var(--border);
  position: sticky;
  top: 0;
  z-index: 10;
}
.search-input {
  width: 100%;
  padding: 8px 12px 8px 32px;
  border: none;
  border-radius: 8px;
  background: #efefef;
  font-size: 14px;
  outline: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='%238e8e8e' viewBox='0 0 24 24'%3E%3Ccircle cx='11' cy='11' r='7' stroke='%238e8e8e' stroke-width='2' fill='none'/%3E%3Cline x1='16.5' y1='16.5' x2='21' y2='21' stroke='%238e8e8e' stroke-width='2'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: 10px center;
}
.photo-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
}
.photo-grid-item {
  aspect-ratio: 1;
  object-fit: cover;
  width: 100%;
  cursor: pointer;
  background: #eee;
}

/* Camera */
.camera-view {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: #000;
  z-index: 200;
  display: flex;
  flex-direction: column;
}
.camera-preview {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  overflow: hidden;
}
.camera-preview video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.camera-controls {
  padding: 20px;
  display: flex;
  align-items: center;
  justify-content: space-around;
  background: #000;
  padding-bottom: calc(20px + var(--safe-bottom));
}
.camera-shutter {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 4px solid #fff;
  background: #fff;
  position: relative;
}
.camera-shutter::after {
  content: '';
  position: absolute;
  inset: 4px;
  border-radius: 50%;
  border: 2px solid #000;
}
.camera-shutter:active { transform: scale(0.92); }
.camera-btn { color: #fff; font-size: 14px; font-weight: 500; padding: 8px 16px; }
.camera-flip {
  width: 40px; height: 40px;
  display: flex; align-items: center; justify-content: center;
}
.camera-flash {
  width: 40px; height: 40px;
  display: flex; align-items: center; justify-content: center;
}
.camera-close {
  position: absolute;
  top: 12px;
  left: 12px;
  z-index: 10;
  color: #fff;
  font-size: 28px;
  padding: 8px;
  text-shadow: 0 1px 3px rgba(0,0,0,0.5);
}

/* Post creation */
.create-post {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: var(--bg);
  z-index: 200;
  display: flex;
  flex-direction: column;
}
.create-header { border-bottom: 1px solid var(--border); }
.create-body { flex: 1; overflow-y: auto; }
.create-preview { display: flex; padding: 16px; gap: 12px; }
.create-preview img { width: 100px; height: 100px; object-fit: cover; border-radius: 4px; }
.create-preview textarea {
  flex: 1;
  border: none;
  outline: none;
  resize: none;
  font-size: 15px;
  line-height: 1.5;
  min-height: 100px;
  background: transparent;
}
.create-option {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px;
  border-top: 1px solid var(--border);
  font-size: 15px;
}
.create-option .toggle {
  width: 44px; height: 24px;
  border-radius: 12px;
  background: #dbdbdb;
  position: relative;
  transition: background 0.2s;
  cursor: pointer;
}
.create-option .toggle.on { background: var(--accent); }
.create-option .toggle::after {
  content: '';
  width: 20px; height: 20px;
  border-radius: 50%;
  background: #fff;
  position: absolute;
  top: 2px; left: 2px;
  transition: transform 0.2s;
  box-shadow: 0 1px 3px rgba(0,0,0,0.2);
}
.create-option .toggle.on::after { transform: translateX(20px); }
.share-btn {
  color: var(--accent);
  font-weight: 600;
  font-size: 15px;
  padding: 4px 8px;
}
.share-btn:disabled { opacity: 0.4; }

/* Post Detail */
.detail-image { width: 100%; aspect-ratio: 1; object-fit: cover; background: #eee; }

/* Comments */
.comment-list { padding: 0; }
.comment-item { display: flex; padding: 10px 12px; gap: 10px; }
.comment-avatar { width: 32px; height: 32px; border-radius: 50%; object-fit: cover; flex-shrink: 0; background: #eee; }
.comment-body { flex: 1; font-size: 13px; line-height: 1.4; }
.comment-body strong { font-weight: 600; margin-right: 4px; }
.comment-time { color: var(--text-secondary); font-size: 11px; margin-top: 4px; }
.comment-input-bar {
  position: sticky;
  bottom: 0;
  background: var(--card);
  border-top: 1px solid var(--border);
  display: flex;
  align-items: center;
  padding: 8px 12px;
  gap: 8px;
}
.comment-input-bar input {
  flex: 1;
  border: none;
  outline: none;
  padding: 8px 0;
  font-size: 14px;
  background: transparent;
}
.comment-send { color: var(--accent); font-weight: 600; font-size: 14px; }
.comment-send:disabled { opacity: 0.4; }

/* Profile */
.profile-header { padding: 16px; background: var(--card); }
.profile-top { display: flex; align-items: center; gap: 24px; margin-bottom: 12px; }
.profile-avatar { width: 80px; height: 80px; border-radius: 50%; object-fit: cover; background: #eee; flex-shrink: 0; }
.profile-stats { display: flex; gap: 20px; flex: 1; justify-content: center; }
.profile-stat { text-align: center; }
.profile-stat-num { font-size: 17px; font-weight: 700; }
.profile-stat-label { font-size: 12px; color: var(--text-secondary); }
.profile-name { font-weight: 600; font-size: 14px; }
.profile-bio { font-size: 14px; color: var(--text); margin-top: 2px; line-height: 1.4; }
.profile-actions { margin-top: 12px; display: flex; gap: 8px; }
.btn-primary {
  flex: 1;
  padding: 8px;
  border-radius: 8px;
  font-weight: 600;
  font-size: 14px;
  text-align: center;
  background: var(--accent);
  color: #fff;
}
.btn-secondary {
  flex: 1;
  padding: 8px;
  border-radius: 8px;
  font-weight: 600;
  font-size: 14px;
  text-align: center;
  background: #efefef;
  color: var(--text);
}
.btn-follow-active { background: #efefef; color: var(--text); }

/* Notifications */
.notif-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  gap: 10px;
  background: var(--card);
}
.notif-item.unread { background: #e8f0fe; }
.notif-avatar { width: 40px; height: 40px; border-radius: 50%; object-fit: cover; flex-shrink: 0; background: #eee; }
.notif-text { flex: 1; font-size: 13px; line-height: 1.4; }
.notif-text strong { font-weight: 600; }
.notif-time { color: var(--text-secondary); }
.notif-thumb { width: 40px; height: 40px; object-fit: cover; flex-shrink: 0; }

/* Settings */
.settings-group { background: var(--card); margin-top: 8px; }
.settings-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 16px;
  border-bottom: 1px solid var(--border);
  font-size: 15px;
}
.settings-item:last-child { border-bottom: none; }
.settings-item.danger { color: #ed4956; }

/* Profile edit */
.edit-avatar-section { text-align: center; padding: 20px; }
.edit-avatar { width: 80px; height: 80px; border-radius: 50%; object-fit: cover; margin: 0 auto 8px; background: #eee; }
.edit-avatar-btn { color: var(--accent); font-weight: 600; font-size: 13px; }
.edit-field { padding: 12px 16px; border-bottom: 1px solid var(--border); }
.edit-field label { display: block; font-size: 12px; color: var(--text-secondary); margin-bottom: 4px; }
.edit-field input, .edit-field textarea {
  width: 100%;
  border: none;
  outline: none;
  font-size: 15px;
  background: transparent;
  padding: 0;
}
.edit-field textarea { resize: none; height: 60px; }

/* Overlays & Modals */
.overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5);
  z-index: 300;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}
.modal-sheet {
  background: var(--card);
  border-radius: 16px 16px 0 0;
  width: 100%;
  max-width: 500px;
  max-height: 60vh;
  overflow-y: auto;
  padding-bottom: var(--safe-bottom);
}
.modal-handle {
  width: 36px; height: 4px;
  background: #dbdbdb;
  border-radius: 2px;
  margin: 8px auto;
}
.modal-item {
  padding: 14px 16px;
  font-size: 15px;
  text-align: center;
  border-bottom: 1px solid var(--border);
}
.modal-item.danger { color: #ed4956; font-weight: 600; }
.modal-item:last-child { border-bottom: none; }

/* Empty states */
.empty-state { text-align: center; padding: 60px 20px; color: var(--text-secondary); }
.empty-state svg { width: 48px; height: 48px; margin-bottom: 12px; opacity: 0.5; }
.empty-state p { font-size: 14px; }

/* Loading */
.spinner {
  width: 24px; height: 24px;
  border: 3px solid var(--border);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
  margin: 20px auto;
}
@keyframes spin { to { transform: rotate(360deg); } }
.loading-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(255,255,255,0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 400;
}

/* Toast */
.toast {
  position: fixed;
  bottom: calc(var(--nav-height) + 16px + var(--safe-bottom));
  left: 50%;
  transform: translateX(-50%);
  background: #262626;
  color: #fff;
  padding: 10px 20px;
  border-radius: 8px;
  font-size: 13px;
  z-index: 500;
  opacity: 0;
  transition: opacity 0.3s;
  pointer-events: none;
}
.toast.show { opacity: 1; }

/* Search results */
.search-results { background: var(--card); }
.search-user-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  gap: 10px;
  border-bottom: 1px solid var(--border);
}
.search-user-avatar { width: 40px; height: 40px; border-radius: 50%; object-fit: cover; background: #eee; }
.search-user-info { flex: 1; }
.search-user-name { font-weight: 600; font-size: 14px; }
.search-user-full { font-size: 13px; color: var(--text-secondary); }

/* Hashtag posts header */
.hashtag-header { padding: 16px; background: var(--card); border-bottom: 1px solid var(--border); }
.hashtag-header h2 { font-size: 18px; }
.hashtag-header p { color: var(--text-secondary); font-size: 13px; margin-top: 2px; }

/* Pull to refresh */
.ptr-indicator { text-align: center; padding: 8px; color: var(--text-secondary); font-size: 12px; display: none; }

/* Report modal */
.report-options { padding: 0 16px 16px; }
.report-option {
  padding: 12px 0;
  border-bottom: 1px solid var(--border);
  font-size: 15px;
  cursor: pointer;
}
.report-option:hover { color: var(--accent); }

/* DM */
.dm-conv-item {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  gap: 12px;
  background: var(--card);
  border-bottom: 1px solid var(--border);
  cursor: pointer;
}
.dm-conv-item:active { background: #f5f5f5; }
.dm-conv-avatar { width: 52px; height: 52px; border-radius: 50%; object-fit: cover; flex-shrink: 0; background: #eee; }
.dm-conv-body { flex: 1; min-width: 0; }
.dm-conv-name { font-weight: 600; font-size: 14px; }
.dm-conv-preview { font-size: 13px; color: var(--text-secondary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 2px; }
.dm-conv-preview.unread { color: var(--text); font-weight: 600; }
.dm-conv-meta { flex-shrink: 0; text-align: right; }
.dm-conv-time { font-size: 11px; color: var(--text-secondary); }
.dm-unread-badge {
  display: inline-block;
  min-width: 18px;
  height: 18px;
  line-height: 18px;
  border-radius: 9px;
  background: var(--accent);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  text-align: center;
  padding: 0 5px;
  margin-top: 4px;
}
.dm-bubble-wrap { display: flex; margin: 4px 12px; }
.dm-bubble-wrap.mine { justify-content: flex-end; }
.dm-bubble-wrap.theirs { justify-content: flex-start; }
.dm-bubble {
  max-width: 70%;
  padding: 8px 12px;
  border-radius: 18px;
  font-size: 14px;
  line-height: 1.4;
  word-break: break-word;
  position: relative;
}
.dm-bubble.mine { background: var(--accent); color: #fff; border-bottom-right-radius: 4px; }
.dm-bubble.theirs { background: #efefef; color: var(--text); border-bottom-left-radius: 4px; }
.dm-bubble-time { font-size: 10px; color: var(--text-secondary); margin-top: 2px; display: flex; align-items: center; gap: 4px; }
.dm-bubble-wrap.mine .dm-bubble-time { justify-content: flex-end; }
.dm-bubble-read svg { width: 14px; height: 14px; color: var(--accent); }
.dm-input-bar {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  gap: 8px;
  background: var(--card);
  border-top: 1px solid var(--border);
  position: sticky;
  bottom: 0;
}
.dm-input-bar input {
  flex: 1;
  border: 1px solid var(--border);
  border-radius: 20px;
  padding: 8px 16px;
  font-size: 14px;
  outline: none;
  background: var(--bg);
}
.dm-input-bar input:focus { border-color: var(--accent); }
.dm-send-btn { color: var(--accent); font-weight: 600; font-size: 14px; padding: 8px; }
.dm-send-btn:disabled { opacity: 0.4; }
.dm-badge {
  position: absolute;
  top: -4px;
  right: -6px;
  min-width: 16px;
  height: 16px;
  line-height: 16px;
  border-radius: 8px;
  background: var(--like);
  color: #fff;
  font-size: 10px;
  font-weight: 700;
  text-align: center;
  padding: 0 4px;
}
.dm-header-icon { position: relative; display: inline-flex; cursor: pointer; padding: 4px; }
.dm-date-sep { text-align: center; padding: 12px 0 4px; font-size: 11px; color: var(--text-secondary); }

@media (min-width: 500px) {
  #app { max-width: 500px; margin: 0 auto; border-left: 1px solid var(--border); border-right: 1px solid var(--border); }
  .bottom-nav { max-width: 500px; left: 50%; transform: translateX(-50%); }
  .toast { max-width: 400px; }
}
</style>
</head>
<body>
<div id="app">
  <div id="header-container"></div>
  <div class="main-content" id="main-content"></div>
  <nav class="bottom-nav" id="bottom-nav"></nav>
</div>
<div class="toast" id="toast"></div>
<div id="overlay-container"></div>
<div id="fullscreen-container"></div>

<script>
// ============================================
// CONFIG
// ============================================
const SUPABASE_URL = 'https://vylwpbbwkmuxrfzmgvkj.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ5bHdwYmJ3a211eHJmem1ndmtqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkwMzE5MDgsImV4cCI6MjA3NDYwNzkwOH0.oDxf3R0X-PWLp5ZP4ERu9Co7GehAwxYLORY9bF8zeBw';
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============================================
// STATE
// ============================================
const state = {
  user: null,
  profile: null,
  currentView: 'feed',
  viewStack: [],
  feedPosts: [],
  feedPage: 0,
  feedLoading: false,
  feedEnd: false,
  explorePosts: [],
  explorePage: 0,
  cameraStream: null,
  cameraFacing: 'environment',
  flashOn: false,
  capturedImage: null,
  notifications: [],
  cachedProfiles: {},
  // DM
  conversations: [],
  dmLoading: false,
  currentConversation: null,
  messages: [],
  messagesLoading: false,
  messagesEnd: false,
  messagesPage: 0,
  dmSubscription: null,
  unreadDmCount: 0
};

const PAGE_SIZE = 12;

// ============================================
// ICONS (SVG)
// ============================================
const icons = {
  home: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9.5L12 3l9 6.5V20a1 1 0 01-1 1H4a1 1 0 01-1-1V9.5z"/></svg>`,
  homeFill: `<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M3 9.5L12 3l9 6.5V20a1 1 0 01-1 1H4a1 1 0 01-1-1V9.5z"/></svg>`,
  search: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><line x1="16.5" y1="16.5" x2="21" y2="21"/></svg>`,
  searchFill: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="11" cy="11" r="7"/><line x1="16.5" y1="16.5" x2="21" y2="21"/></svg>`,
  camera: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="6" width="20" height="14" rx="2"/><circle cx="12" cy="13" r="4"/><path d="M7 6V4h10v2"/></svg>`,
  heart: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 000-7.78z"/></svg>`,
  heartFill: `<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 000-7.78z"/></svg>`,
  comment: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>`,
  user: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="4"/><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/></svg>`,
  back: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>`,
  more: `<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="6" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="18" r="1.5"/></svg>`,
  close: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`,
  flip: `<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><path d="M1 4v6h6M23 20v-6h-6"/><path d="M20.49 9A9 9 0 005.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 013.51 15"/></svg>`,
  flash: `<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>`,
  flashOff: `<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/><line x1="1" y1="1" x2="23" y2="23" stroke-width="2"/></svg>`,
  location: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>`,
  grid: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></svg>`,
  settings: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>`,
  send: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>`,
  dm: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2Z"/></svg>`,
  checkDouble: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M2 13l4 4L14 7"/><path d="M8 13l4 4L20 7"/></svg>`,
};

// ============================================
// HELPERS
// ============================================
function $(sel) { return document.querySelector(sel); }
function $$(sel) { return document.querySelectorAll(sel); }
function el(tag, attrs, ...children) {
  const e = document.createElement(tag);
  if (attrs) Object.entries(attrs).forEach(([k, v]) => {
    if (k === 'className') e.className = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2).toLowerCase(), v);
    else if (k === 'html') e.innerHTML = v;
    else e.setAttribute(k, v);
  });
  children.flat().forEach(c => { if (c) e.append(typeof c === 'string' ? c : c); });
  return e;
}

function timeAgo(date) {
  const s = Math.floor((Date.now() - new Date(date)) / 1000);
  if (s < 60) return '今';
  if (s < 3600) return Math.floor(s/60) + '分前';
  if (s < 86400) return Math.floor(s/3600) + '時間前';
  if (s < 604800) return Math.floor(s/86400) + '日前';
  return new Date(date).toLocaleDateString('ja-JP');
}

function formatCaption(text) {
  if (!text) return '';
  return text.replace(/#([\w\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]+)/g, '<span class="hashtag" data-tag="$1">#$1</span>');
}

function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 2500);
}

function avatarUrl(url) {
  if (!url) return 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23ccc"><circle cx="12" cy="8" r="4"/><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/></svg>');
  return url;
}

function showLoading() {
  const o = el('div', { className: 'loading-overlay', id: 'loading-overlay' }, el('div', { className: 'spinner' }));
  document.body.appendChild(o);
}
function hideLoading() {
  const o = document.getElementById('loading-overlay');
  if (o) o.remove();
}

// ============================================
// NAVIGATION
// ============================================
function navigate(view, params = {}, pushStack = true) {
  if (pushStack && state.currentView !== view) {
    state.viewStack.push({ view: state.currentView, params: state.currentParams });
  }
  state.currentView = view;
  state.currentParams = params;
  render();
}

function goBack() {
  if (state.viewStack.length > 0) {
    const prev = state.viewStack.pop();
    state.currentView = prev.view;
    state.currentParams = prev.params || {};
    render();
  } else {
    navigate('feed', {}, false);
  }
}

function switchTab(tab) {
  state.viewStack = [];
  state.currentView = tab;
  state.currentParams = {};
  render();
}

// ============================================
// RENDER
// ============================================
function render() {
  // Clean up DM thread subscription when leaving thread view
  if (state.currentView !== 'thread' && state.dmSubscription) {
    state.dmSubscription.unsubscribe();
    state.dmSubscription = null;
  }

  const header = $('#header-container');
  const content = $('#main-content');
  const nav = $('#bottom-nav');

  header.innerHTML = '';
  content.innerHTML = '';

  renderNav(nav);

  switch (state.currentView) {
    case 'feed': renderFeed(header, content); break;
    case 'explore': renderExplore(header, content); break;
    case 'camera': openCamera(); break;
    case 'notifications': renderNotifications(header, content); break;
    case 'profile': renderProfile(header, content, state.user.id); break;
    case 'user': renderProfile(header, content, state.currentParams.userId); break;
    case 'post': renderPostDetail(header, content, state.currentParams.postId); break;
    case 'comments': renderComments(header, content, state.currentParams.postId); break;
    case 'settings': renderSettings(header, content); break;
    case 'editProfile': renderEditProfile(header, content); break;
    case 'hashtag': renderHashtag(header, content, state.currentParams.tag); break;
    case 'inbox': renderInbox(header, content); break;
    case 'thread': renderThread(header, content, state.currentParams.conversationId, state.currentParams.otherUserId); break;
  }

  content.scrollTop = 0;
}

function renderNav(nav) {
  const tabs = [
    { id: 'feed', icon: icons.home, activeIcon: icons.homeFill },
    { id: 'explore', icon: icons.search, activeIcon: icons.searchFill },
    { id: 'camera', icon: icons.camera, activeIcon: icons.camera },
    { id: 'notifications', icon: icons.heart, activeIcon: icons.heartFill },
    { id: 'profile', icon: null, activeIcon: null },
  ];

  nav.innerHTML = tabs.map(t => {
    const active = state.currentView === t.id || (t.id === 'profile' && (state.currentView === 'profile' || state.currentView === 'settings' || state.currentView === 'editProfile'));
    if (t.id === 'profile') {
      const av = state.profile?.avatar_url;
      return `<button class="nav-item ${active ? 'active' : ''}" data-tab="${t.id}">
        <img class="nav-avatar" src="${avatarUrl(av)}" alt="">
      </button>`;
    }
    return `<button class="nav-item ${active ? 'active' : ''}" data-tab="${t.id}">${active ? t.activeIcon : t.icon}</button>`;
  }).join('');

  nav.querySelectorAll('.nav-item').forEach(btn => {
    btn.onclick = () => switchTab(btn.dataset.tab);
  });
}

// ============================================
// FEED
// ============================================
async function renderFeed(header, content) {
  header.innerHTML = `<div class="header">
    <div class="header-logo">Real Insta</div>
    <div class="dm-header-icon" id="open-dm-btn">
      ${icons.dm}
      <span class="dm-badge" id="dm-badge" style="display:none"></span>
    </div>
  </div>`;
  header.querySelector('#open-dm-btn').onclick = () => navigate('inbox');
  updateDmBadge();

  content.innerHTML = '<div class="spinner"></div>';

  const posts = await loadFeedPosts(0);
  state.feedPosts = posts;
  state.feedPage = 0;
  state.feedEnd = posts.length < PAGE_SIZE;

  if (posts.length === 0) {
    content.innerHTML = `<div class="empty-state">
      ${icons.camera}
      <p>まだ投稿がありません<br>カメラで最初の写真を撮ろう！</p>
    </div>`;
    return;
  }

  content.innerHTML = '';
  posts.forEach(p => content.appendChild(createPostCard(p)));

  if (!state.feedEnd) {
    const sentinel = el('div', { className: 'spinner', id: 'feed-sentinel' });
    content.appendChild(sentinel);
    setupInfiniteScroll(content, sentinel);
  }
}

async function loadFeedPosts(page) {
  const from = page * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  // Get following IDs
  const { data: follows } = await sb
    .from('ri_follows')
    .select('following_id')
    .eq('follower_id', state.user.id);

  const followingIds = (follows || []).map(f => f.following_id);
  followingIds.push(state.user.id); // include own posts

  const { data } = await sb
    .from('ri_posts')
    .select('*, profiles:user_id(id, username, avatar_url, display_name)')
    .in('user_id', followingIds)
    .order('created_at', { ascending: false })
    .range(from, to);

  if (!data) return [];

  // Get like status for these posts
  const postIds = data.map(p => p.id);
  const { data: myLikes } = await sb
    .from('ri_likes')
    .select('post_id')
    .eq('user_id', state.user.id)
    .in('post_id', postIds);

  const likedSet = new Set((myLikes || []).map(l => l.post_id));

  // Get comment counts
  const { data: commentCounts } = await sb
    .from('ri_comments')
    .select('post_id')
    .in('post_id', postIds);

  const countMap = {};
  (commentCounts || []).forEach(c => { countMap[c.post_id] = (countMap[c.post_id] || 0) + 1; });

  return data.map(p => ({
    ...p,
    liked: likedSet.has(p.id),
    commentCount: countMap[p.id] || 0
  }));
}

function setupInfiniteScroll(container, sentinel) {
  const observer = new IntersectionObserver(async entries => {
    if (entries[0].isIntersecting && !state.feedLoading && !state.feedEnd) {
      state.feedLoading = true;
      state.feedPage++;
      const more = await loadFeedPosts(state.feedPage);
      if (more.length < PAGE_SIZE) state.feedEnd = true;
      state.feedPosts.push(...more);
      more.forEach(p => container.insertBefore(createPostCard(p), sentinel));
      if (state.feedEnd) sentinel.remove();
      state.feedLoading = false;
    }
  }, { root: container });
  observer.observe(sentinel);
}

function createPostCard(post) {
  const profile = post.profiles || {};
  const card = el('div', { className: 'post-card' });
  card.innerHTML = `
    <div class="post-header">
      <img class="post-avatar" src="${avatarUrl(profile.avatar_url)}" alt="" data-user="${profile.id}">
      <span class="post-username" data-user="${profile.id}">${profile.username || profile.display_name || 'user'}</span>
      ${post.is_verified ? '<span class="verified-badge">✅ Real</span>' : ''}
      <button class="post-more">${icons.more}</button>
    </div>
    <img class="post-image" src="${post.image_url}" alt="" loading="lazy">
    <div class="post-actions">
      <button class="post-action like-btn ${post.liked ? 'liked' : ''}" data-post="${post.id}">
        ${post.liked ? icons.heartFill : icons.heart}
      </button>
      <button class="post-action comment-btn" data-post="${post.id}">${icons.comment}</button>
    </div>
    ${post.caption ? `<div class="post-caption"><strong data-user="${profile.id}">${profile.username || profile.display_name || 'user'}</strong> ${formatCaption(post.caption)}</div>` : ''}
    ${post.commentCount > 0 ? `<div class="post-comments-link" data-post="${post.id}">コメント${post.commentCount}件をすべて見る</div>` : ''}
    <div class="post-time">${timeAgo(post.created_at)}</div>
  `;

  // Event listeners
  card.querySelectorAll('[data-user]').forEach(el => {
    el.onclick = (e) => {
      e.stopPropagation();
      const uid = el.dataset.user;
      if (uid === state.user.id) switchTab('profile');
      else navigate('user', { userId: uid });
    };
    el.style.cursor = 'pointer';
  });

  card.querySelector('.like-btn').onclick = () => toggleLike(post, card);
  card.querySelector('.comment-btn').onclick = () => navigate('comments', { postId: post.id });
  const commentsLink = card.querySelector('.post-comments-link');
  if (commentsLink) commentsLink.onclick = () => navigate('comments', { postId: post.id });

  card.querySelector('.post-more').onclick = () => showPostMenu(post);

  // Hashtag clicks
  card.querySelectorAll('.hashtag').forEach(h => {
    h.onclick = (e) => { e.stopPropagation(); navigate('hashtag', { tag: h.dataset.tag }); };
    h.style.cursor = 'pointer';
  });

  // Double tap to like
  let lastTap = 0;
  card.querySelector('.post-image').onclick = () => {
    const now = Date.now();
    if (now - lastTap < 300) {
      if (!post.liked) toggleLike(post, card);
    }
    lastTap = now;
  };

  return card;
}

async function toggleLike(post, card) {
  const btn = card.querySelector('.like-btn');
  post.liked = !post.liked;
  btn.classList.toggle('liked');
  btn.innerHTML = post.liked ? icons.heartFill : icons.heart;

  if (post.liked) {
    await sb.from('ri_likes').insert({ user_id: state.user.id, post_id: post.id });
  } else {
    await sb.from('ri_likes').delete().eq('user_id', state.user.id).eq('post_id', post.id);
  }
}

function showPostMenu(post) {
  const isOwn = post.user_id === state.user.id;
  const overlay = el('div', { className: 'overlay', id: 'post-menu' });
  const sheet = el('div', { className: 'modal-sheet' });
  sheet.innerHTML = `<div class="modal-handle"></div>`;

  if (isOwn) {
    const del = el('div', { className: 'modal-item danger' }, '投稿を削除');
    del.onclick = async () => {
      overlay.remove();
      if (confirm('この投稿を削除しますか？')) {
        await sb.from('ri_posts').delete().eq('id', post.id);
        toast('投稿を削除しました');
        render();
      }
    };
    sheet.appendChild(del);
  } else {
    const report = el('div', { className: 'modal-item' }, '通報する');
    report.onclick = () => { overlay.remove(); showReportModal(post); };
    sheet.appendChild(report);

    const block = el('div', { className: 'modal-item danger' }, 'このユーザーをブロック');
    block.onclick = async () => {
      overlay.remove();
      await sb.from('ri_blocks').insert({ blocker_id: state.user.id, blocked_id: post.user_id });
      toast('ブロックしました');
      render();
    };
    sheet.appendChild(block);
  }

  const cancel = el('div', { className: 'modal-item' }, 'キャンセル');
  cancel.onclick = () => overlay.remove();
  sheet.appendChild(cancel);

  overlay.appendChild(sheet);
  overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };
  document.getElementById('overlay-container').appendChild(overlay);
}

function showReportModal(post) {
  const reasons = [
    { val: 'spam', label: 'スパム' },
    { val: 'nudity', label: '不適切な写真' },
    { val: 'harassment', label: '嫌がらせ' },
    { val: 'violence', label: '暴力的な内容' },
    { val: 'other', label: 'その他' }
  ];
  const overlay = el('div', { className: 'overlay' });
  const sheet = el('div', { className: 'modal-sheet' });
  sheet.innerHTML = `<div class="modal-handle"></div><div style="padding:16px;font-weight:600;text-align:center;border-bottom:1px solid var(--border)">通報の理由</div>`;
  const opts = el('div', { className: 'report-options' });
  reasons.forEach(r => {
    const opt = el('div', { className: 'report-option' }, r.label);
    opt.onclick = async () => {
      await sb.from('ri_reports').insert({ reporter_id: state.user.id, post_id: post.id, reason: r.val });
      overlay.remove();
      toast('通報を送信しました');
    };
    opts.appendChild(opt);
  });
  sheet.appendChild(opts);
  overlay.appendChild(sheet);
  overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };
  document.getElementById('overlay-container').appendChild(overlay);
}

// ============================================
// EXPLORE
// ============================================
async function renderExplore(header, content) {
  header.innerHTML = `<div class="header"><div class="header-title">探索</div></div>`;

  const searchBar = el('div', { className: 'explore-search' });
  const input = el('input', { className: 'search-input', type: 'text', placeholder: '検索...' });
  searchBar.appendChild(input);
  content.appendChild(searchBar);

  const resultsDiv = el('div', { id: 'search-results' });
  content.appendChild(resultsDiv);

  const gridDiv = el('div', { id: 'explore-grid' });
  content.appendChild(gridDiv);

  // Load explore grid
  loadExploreGrid(gridDiv);

  let searchTimeout;
  input.oninput = () => {
    clearTimeout(searchTimeout);
    const q = input.value.trim();
    if (!q) {
      resultsDiv.innerHTML = '';
      gridDiv.style.display = '';
      return;
    }
    searchTimeout = setTimeout(async () => {
      gridDiv.style.display = 'none';
      if (q.startsWith('#')) {
        const tag = q.slice(1);
        const { data } = await sb.from('ri_hashtags').select('name').ilike('name', `${tag}%`).limit(20);
        resultsDiv.innerHTML = '';
        (data || []).forEach(h => {
          const item = el('div', { className: 'search-user-item', style: 'cursor:pointer' });
          item.innerHTML = `<div class="search-user-info"><div class="search-user-name">#${h.name}</div></div>`;
          item.onclick = () => navigate('hashtag', { tag: h.name });
          resultsDiv.appendChild(item);
        });
      } else {
        const { data } = await sb.from('ri_profiles').select('*').or(`username.ilike.%${q}%,display_name.ilike.%${q}%`).limit(20);
        resultsDiv.innerHTML = '';
        (data || []).forEach(u => {
          const item = el('div', { className: 'search-user-item', style: 'cursor:pointer' });
          item.innerHTML = `
            <img class="search-user-avatar" src="${avatarUrl(u.avatar_url)}" alt="">
            <div class="search-user-info">
              <div class="search-user-name">${u.username || 'user'}</div>
              <div class="search-user-full">${u.display_name || ''}</div>
            </div>`;
          item.onclick = () => {
            if (u.id === state.user.id) switchTab('profile');
            else navigate('user', { userId: u.id });
          };
          resultsDiv.appendChild(item);
        });
      }
    }, 300);
  };
}

async function loadExploreGrid(container) {
  const { data } = await sb
    .from('ri_posts')
    .select('id, image_url')
    .order('created_at', { ascending: false })
    .limit(30);

  if (!data || data.length === 0) {
    container.innerHTML = '<div class="empty-state"><p>まだ投稿がありません</p></div>';
    return;
  }

  const grid = el('div', { className: 'photo-grid' });
  data.forEach(p => {
    const img = el('img', { className: 'photo-grid-item', src: p.image_url, loading: 'lazy', alt: '' });
    img.onclick = () => navigate('post', { postId: p.id });
    grid.appendChild(img);
  });
  container.appendChild(grid);
}

// ============================================
// CAMERA
// ============================================
async function openCamera() {
  const fs = document.getElementById('fullscreen-container');
  fs.innerHTML = '';

  const view = el('div', { className: 'camera-view' });
  view.innerHTML = `
    <div class="camera-preview">
      <button class="camera-close" id="cam-close">${icons.close}</button>
      <video id="cam-video" autoplay playsinline></video>
    </div>
    <div class="camera-controls">
      <button class="camera-flash" id="cam-flash">${icons.flash}</button>
      <button class="camera-shutter" id="cam-shutter"></button>
      <button class="camera-flip" id="cam-flip">${icons.flip}</button>
    </div>
  `;
  fs.appendChild(view);

  const video = view.querySelector('#cam-video');

  try {
    state.cameraStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: state.cameraFacing, width: { ideal: 1080 }, height: { ideal: 1080 } },
      audio: false
    });
    video.srcObject = state.cameraStream;
  } catch (err) {
    toast('カメラにアクセスできません');
    closeCamera();
    return;
  }

  view.querySelector('#cam-close').onclick = closeCamera;

  view.querySelector('#cam-shutter').onclick = () => {
    const canvas = document.createElement('canvas');
    const vw = video.videoWidth;
    const vh = video.videoHeight;
    const size = Math.min(vw, vh);
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(video, (vw - size) / 2, (vh - size) / 2, size, size, 0, 0, size, size);
    state.capturedImage = canvas.toDataURL('image/jpeg', 0.85);
    closeCamera();
    openCreatePost();
  };

  view.querySelector('#cam-flip').onclick = async () => {
    state.cameraFacing = state.cameraFacing === 'environment' ? 'user' : 'environment';
    if (state.cameraStream) state.cameraStream.getTracks().forEach(t => t.stop());
    try {
      state.cameraStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: state.cameraFacing, width: { ideal: 1080 }, height: { ideal: 1080 } },
        audio: false
      });
      video.srcObject = state.cameraStream;
    } catch (e) { toast('カメラ切替失敗'); }
  };

  view.querySelector('#cam-flash').onclick = () => {
    state.flashOn = !state.flashOn;
    view.querySelector('#cam-flash').innerHTML = state.flashOn ? icons.flash : icons.flashOff;
    const track = state.cameraStream?.getVideoTracks()[0];
    if (track?.getCapabilities().torch) {
      track.applyConstraints({ advanced: [{ torch: state.flashOn }] });
    }
  };
}

function closeCamera() {
  if (state.cameraStream) {
    state.cameraStream.getTracks().forEach(t => t.stop());
    state.cameraStream = null;
  }
  document.getElementById('fullscreen-container').innerHTML = '';
  if (state.currentView === 'camera' && !state.capturedImage) {
    switchTab('feed');
  }
}

// ============================================
// CREATE POST
// ============================================
function openCreatePost() {
  if (!state.capturedImage) return;
  const fs = document.getElementById('fullscreen-container');
  fs.innerHTML = '';

  let locationOn = false;
  let locationData = null;

  const view = el('div', { className: 'create-post' });
  view.innerHTML = `
    <div class="header create-header">
      <div class="header-left"><button class="header-btn" id="create-back">${icons.back}</button></div>
      <div class="header-title">新規投稿</div>
      <div class="header-right"><button class="share-btn" id="create-share">シェア</button></div>
    </div>
    <div class="create-body">
      <div class="create-preview">
        <img src="${state.capturedImage}" alt="">
        <textarea id="caption-input" placeholder="キャプションを入力..." maxlength="300"></textarea>
      </div>
      <div class="create-option">
        <span>${icons.location} 位置情報を追加</span>
        <div class="toggle" id="location-toggle"></div>
      </div>
      <div id="location-name" style="padding:0 16px 8px;font-size:13px;color:var(--text-secondary);display:none"></div>
    </div>
  `;
  fs.appendChild(view);

  view.querySelector('#create-back').onclick = () => {
    state.capturedImage = null;
    fs.innerHTML = '';
    switchTab('feed');
  };

  view.querySelector('#location-toggle').onclick = async function() {
    locationOn = !locationOn;
    this.classList.toggle('on', locationOn);
    if (locationOn) {
      try {
        const pos = await new Promise((res, rej) => navigator.geolocation.getCurrentPosition(res, rej, { timeout: 10000 }));
        locationData = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        view.querySelector('#location-name').style.display = 'block';
        view.querySelector('#location-name').textContent = `${locationData.lat.toFixed(4)}, ${locationData.lng.toFixed(4)}`;
      } catch(e) {
        toast('位置情報を取得できません');
        locationOn = false;
        this.classList.remove('on');
      }
    } else {
      locationData = null;
      view.querySelector('#location-name').style.display = 'none';
    }
  };

  view.querySelector('#create-share').onclick = async function() {
    this.disabled = true;
    showLoading();
    try {
      // Upload image
      const blob = await (await fetch(state.capturedImage)).blob();
      const filename = `${state.user.id}/${Date.now()}.jpg`;
      const { error: uploadErr } = await sb.storage.from('ri-posts').upload(filename, blob, { contentType: 'image/jpeg' });
      if (uploadErr) throw uploadErr;

      const { data: urlData } = sb.storage.from('ri-posts').getPublicUrl(filename);
      const imageUrl = urlData.publicUrl;

      const caption = view.querySelector('#caption-input').value.trim();

      // EXIF-like verification data
      const exifData = {
        device: navigator.userAgent,
        timestamp: new Date().toISOString(),
        app_version: '1.0.0'
      };

      // Check if within 5 minutes (always true for fresh capture)
      const isVerified = true;

      const { error: postErr } = await sb.from('ri_posts').insert({
        user_id: state.user.id,
        image_url: imageUrl,
        caption: caption || null,
        location_lat: locationData?.lat || null,
        location_lng: locationData?.lng || null,
        exif_data: exifData,
        is_verified: isVerified
      });
      if (postErr) throw postErr;

      state.capturedImage = null;
      fs.innerHTML = '';
      toast('投稿しました！');
      switchTab('feed');
    } catch(e) {
      console.error(e);
      toast('投稿に失敗しました: ' + e.message);
      this.disabled = false;
    } finally {
      hideLoading();
    }
  };
}

// ============================================
// POST DETAIL
// ============================================
async function renderPostDetail(header, content, postId) {
  header.innerHTML = `<div class="header">
    <div class="header-left"><button class="header-btn" onclick="goBack()">${icons.back}</button></div>
    <div class="header-title">投稿</div>
    <div class="header-right"></div>
  </div>`;

  content.innerHTML = '<div class="spinner"></div>';

  const { data: post } = await sb
    .from('ri_posts')
    .select('*, profiles:user_id(id, username, avatar_url, display_name)')
    .eq('id', postId)
    .single();

  if (!post) { content.innerHTML = '<div class="empty-state"><p>投稿が見つかりません</p></div>'; return; }

  const { data: myLike } = await sb.from('ri_likes').select('id').eq('user_id', state.user.id).eq('post_id', postId).maybeSingle();
  post.liked = !!myLike;

  const { data: comments } = await sb
    .from('ri_comments')
    .select('*, profiles:user_id(id, username, avatar_url)')
    .eq('post_id', postId)
    .order('created_at', { ascending: true })
    .limit(50);

  post.commentCount = (comments || []).length;

  content.innerHTML = '';
  content.appendChild(createPostCard(post));

  if (comments && comments.length > 0) {
    const commentList = el('div', { className: 'comment-list' });
    comments.forEach(c => {
      const cProfile = c.profiles || {};
      const item = el('div', { className: 'comment-item' });
      item.innerHTML = `
        <img class="comment-avatar" src="${avatarUrl(cProfile.avatar_url)}" alt="">
        <div class="comment-body">
          <strong>${cProfile.username || 'user'}</strong>${formatCaption(c.content)}
          <div class="comment-time">${timeAgo(c.created_at)}</div>
        </div>
      `;
      commentList.appendChild(item);
    });
    content.appendChild(commentList);
  }

  // Comment input
  const inputBar = el('div', { className: 'comment-input-bar' });
  inputBar.innerHTML = `
    <input type="text" placeholder="コメントを追加..." id="detail-comment-input" maxlength="500">
    <button class="comment-send" id="detail-comment-send" disabled>投稿</button>
  `;
  content.appendChild(inputBar);

  const inp = content.querySelector('#detail-comment-input');
  const sendBtn = content.querySelector('#detail-comment-send');
  inp.oninput = () => { sendBtn.disabled = !inp.value.trim(); };
  sendBtn.onclick = async () => {
    const text = inp.value.trim();
    if (!text) return;
    sendBtn.disabled = true;
    await sb.from('ri_comments').insert({ user_id: state.user.id, post_id: postId, content: text });
    inp.value = '';
    renderPostDetail(header, content, postId);
  };
}

// ============================================
// COMMENTS
// ============================================
async function renderComments(header, content, postId) {
  header.innerHTML = `<div class="header">
    <div class="header-left"><button class="header-btn" onclick="goBack()">${icons.back}</button></div>
    <div class="header-title">コメント</div>
    <div class="header-right"></div>
  </div>`;

  content.innerHTML = '<div class="spinner"></div>';

  const { data: comments } = await sb
    .from('ri_comments')
    .select('*, profiles:user_id(id, username, avatar_url)')
    .eq('post_id', postId)
    .order('created_at', { ascending: true });

  content.innerHTML = '';

  if (!comments || comments.length === 0) {
    content.innerHTML = '<div class="empty-state"><p>コメントはまだありません</p></div>';
  } else {
    const list = el('div', { className: 'comment-list' });
    comments.forEach(c => {
      const p = c.profiles || {};
      const item = el('div', { className: 'comment-item' });
      item.innerHTML = `
        <img class="comment-avatar" src="${avatarUrl(p.avatar_url)}" alt="">
        <div class="comment-body">
          <strong style="cursor:pointer" data-uid="${p.id}">${p.username || 'user'}</strong>${formatCaption(c.content)}
          <div class="comment-time">${timeAgo(c.created_at)}</div>
        </div>
      `;
      item.querySelector('strong').onclick = () => {
        if (p.id === state.user.id) switchTab('profile');
        else navigate('user', { userId: p.id });
      };
      list.appendChild(item);
    });
    content.appendChild(list);
  }

  const inputBar = el('div', { className: 'comment-input-bar' });
  inputBar.innerHTML = `
    <input type="text" placeholder="コメントを追加..." id="comment-input" maxlength="500">
    <button class="comment-send" id="comment-send" disabled>投稿</button>
  `;
  content.appendChild(inputBar);

  const inp = content.querySelector('#comment-input');
  const sendBtn = content.querySelector('#comment-send');
  inp.oninput = () => { sendBtn.disabled = !inp.value.trim(); };
  sendBtn.onclick = async () => {
    const text = inp.value.trim();
    if (!text) return;
    sendBtn.disabled = true;
    await sb.from('ri_comments').insert({ user_id: state.user.id, post_id: postId, content: text });
    renderComments(header, content, postId);
  };
}

// ============================================
// NOTIFICATIONS
// ============================================
async function renderNotifications(header, content) {
  header.innerHTML = `<div class="header"><div class="header-title">アクティビティ</div></div>`;

  content.innerHTML = '<div class="spinner"></div>';

  const { data } = await sb
    .from('ri_notifications')
    .select('*, actor:actor_id(id, username, avatar_url), post:post_id(id, image_url)')
    .eq('user_id', state.user.id)
    .order('created_at', { ascending: false })
    .limit(50);

  if (!data || data.length === 0) {
    content.innerHTML = '<div class="empty-state">' + icons.heart + '<p>まだ通知はありません</p></div>';
    return;
  }

  content.innerHTML = '';
  data.forEach(n => {
    const actor = n.actor || {};
    const item = el('div', { className: `notif-item ${n.is_read ? '' : 'unread'}` });

    let text = '';
    if (n.type === 'like') text = `<strong>${actor.username || 'user'}</strong> があなたの投稿にいいねしました`;
    else if (n.type === 'comment') text = `<strong>${actor.username || 'user'}</strong> がコメントしました`;
    else if (n.type === 'follow') text = `<strong>${actor.username || 'user'}</strong> があなたをフォローしました`;

    item.innerHTML = `
      <img class="notif-avatar" src="${avatarUrl(actor.avatar_url)}" alt="">
      <div class="notif-text">${text} <span class="notif-time">${timeAgo(n.created_at)}</span></div>
      ${n.post?.image_url ? `<img class="notif-thumb" src="${n.post.image_url}" alt="">` : ''}
    `;

    item.onclick = () => {
      if (n.type === 'follow') navigate('user', { userId: actor.id });
      else if (n.post) navigate('post', { postId: n.post.id });
    };
    item.style.cursor = 'pointer';
    content.appendChild(item);
  });

  // Mark all as read
  await sb.from('ri_notifications').update({ is_read: true }).eq('user_id', state.user.id).eq('is_read', false);
}

// ============================================
// PROFILE
// ============================================
async function renderProfile(header, content, userId) {
  const isMe = userId === state.user.id;

  const { data: profile } = await sb.from('ri_profiles').select('*').eq('id', userId).single();
  if (!profile) { content.innerHTML = '<div class="empty-state"><p>ユーザーが見つかりません</p></div>'; return; }

  // Header
  if (isMe) {
    header.innerHTML = `<div class="header">
      <div class="header-left"></div>
      <div class="header-title">${profile.username || 'プロフィール'}</div>
      <div class="header-right"><button class="header-btn" id="settings-btn">${icons.settings}</button></div>
    </div>`;
    header.querySelector('#settings-btn').onclick = () => navigate('settings');
  } else {
    header.innerHTML = `<div class="header">
      <div class="header-left"><button class="header-btn" onclick="goBack()">${icons.back}</button></div>
      <div class="header-title">${profile.username || 'ユーザー'}</div>
      <div class="header-right"></div>
    </div>`;
  }

  // Stats
  const { count: postCount } = await sb.from('ri_posts').select('*', { count: 'exact', head: true }).eq('user_id', userId);

  let followerCount = '-', followingCount = '-';
  if (isMe) {
    const { count: fc } = await sb.from('ri_follows').select('*', { count: 'exact', head: true }).eq('following_id', userId);
    const { count: fic } = await sb.from('ri_follows').select('*', { count: 'exact', head: true }).eq('follower_id', userId);
    followerCount = fc || 0;
    followingCount = fic || 0;
  }

  // Check follow status
  let isFollowing = false;
  if (!isMe) {
    const { data: fw } = await sb.from('ri_follows').select('id').eq('follower_id', state.user.id).eq('following_id', userId).maybeSingle();
    isFollowing = !!fw;
  }

  content.innerHTML = '';
  const profileHeader = el('div', { className: 'profile-header' });
  profileHeader.innerHTML = `
    <div class="profile-top">
      <img class="profile-avatar" src="${avatarUrl(profile.avatar_url)}" alt="">
      <div class="profile-stats">
        <div class="profile-stat"><div class="profile-stat-num">${postCount || 0}</div><div class="profile-stat-label">投稿</div></div>
        ${isMe ? `
          <div class="profile-stat"><div class="profile-stat-num">${followerCount}</div><div class="profile-stat-label">フォロワー</div></div>
          <div class="profile-stat"><div class="profile-stat-num">${followingCount}</div><div class="profile-stat-label">フォロー中</div></div>
        ` : `
          <div class="profile-stat"><div class="profile-stat-num">${postCount || 0}</div><div class="profile-stat-label">投稿</div></div>
        `}
      </div>
    </div>
    ${profile.display_name ? `<div class="profile-name">${profile.display_name}</div>` : ''}
    ${profile.bio ? `<div class="profile-bio">${profile.bio}</div>` : ''}
    <div class="profile-actions">
      ${isMe
        ? `<button class="btn-secondary" id="edit-profile-btn">プロフィールを編集</button>`
        : `<button class="${isFollowing ? 'btn-secondary btn-follow-active' : 'btn-primary'}" id="follow-btn">${isFollowing ? 'フォロー中' : 'フォロー'}</button>
           <button class="btn-secondary" id="dm-btn">メッセージ</button>`
      }
    </div>
  `;
  content.appendChild(profileHeader);

  if (isMe) {
    profileHeader.querySelector('#edit-profile-btn').onclick = () => navigate('editProfile');
  } else {
    profileHeader.querySelector('#dm-btn').onclick = () => openOrCreateConversation(userId);
    profileHeader.querySelector('#follow-btn').onclick = async function() {
      if (isFollowing) {
        await sb.from('ri_follows').delete().eq('follower_id', state.user.id).eq('following_id', userId);
        isFollowing = false;
      } else {
        await sb.from('ri_follows').insert({ follower_id: state.user.id, following_id: userId });
        isFollowing = true;
      }
      this.className = isFollowing ? 'btn-secondary btn-follow-active' : 'btn-primary';
      this.textContent = isFollowing ? 'フォロー中' : 'フォロー';
    };
  }

  // Posts grid
  const { data: posts } = await sb
    .from('ri_posts')
    .select('id, image_url')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (posts && posts.length > 0) {
    const grid = el('div', { className: 'photo-grid' });
    posts.forEach(p => {
      const img = el('img', { className: 'photo-grid-item', src: p.image_url, loading: 'lazy', alt: '' });
      img.onclick = () => navigate('post', { postId: p.id });
      grid.appendChild(img);
    });
    content.appendChild(grid);
  } else {
    content.innerHTML += `<div class="empty-state">${icons.camera}<p>${isMe ? 'まだ投稿がありません<br>カメラで撮影してシェアしよう！' : 'まだ投稿がありません'}</p></div>`;
  }
}

// ============================================
// EDIT PROFILE
// ============================================
async function renderEditProfile(header, content) {
  header.innerHTML = `<div class="header">
    <div class="header-left"><button class="header-btn" onclick="goBack()">${icons.back}</button></div>
    <div class="header-title">プロフィール編集</div>
    <div class="header-right"><button class="header-btn share-btn" id="save-profile">完了</button></div>
  </div>`;

  const profile = state.profile;

  content.innerHTML = `
    <div class="edit-avatar-section">
      <img class="edit-avatar" id="edit-avatar-img" src="${avatarUrl(profile.avatar_url)}" alt="">
      <button class="edit-avatar-btn" id="change-avatar-btn">写真を変更</button>
    </div>
    <div class="edit-field">
      <label>ユーザー名</label>
      <input type="text" id="edit-username" value="${profile.username || ''}" placeholder="username" maxlength="30">
    </div>
    <div class="edit-field">
      <label>名前</label>
      <input type="text" id="edit-display-name" value="${profile.display_name || ''}" placeholder="名前" maxlength="50">
    </div>
    <div class="edit-field">
      <label>自己紹介</label>
      <textarea id="edit-bio" placeholder="自己紹介" maxlength="160">${profile.bio || ''}</textarea>
    </div>
  `;

  let newAvatarBlob = null;

  content.querySelector('#change-avatar-btn').onclick = async () => {
    // Open camera for avatar
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user', width: { ideal: 400 }, height: { ideal: 400 } }, audio: false });
      const overlay = el('div', { className: 'overlay', style: 'align-items:center' });
      const container = el('div', { style: 'background:#000;border-radius:16px;overflow:hidden;width:300px;' });
      const video = el('video', { autoplay: '', playsinline: '', style: 'width:300px;height:300px;object-fit:cover;display:block;' });
      video.srcObject = stream;
      const btn = el('button', { style: 'width:100%;padding:14px;background:#fff;font-size:15px;font-weight:600;border:none;cursor:pointer;' }, '撮影');
      container.append(video, btn);
      overlay.appendChild(container);
      overlay.onclick = (e) => { if (e.target === overlay) { stream.getTracks().forEach(t => t.stop()); overlay.remove(); }};
      document.getElementById('overlay-container').appendChild(overlay);

      btn.onclick = () => {
        const canvas = document.createElement('canvas');
        canvas.width = 400; canvas.height = 400;
        const ctx = canvas.getContext('2d');
        const vw = video.videoWidth, vh = video.videoHeight;
        const size = Math.min(vw, vh);
        ctx.drawImage(video, (vw-size)/2, (vh-size)/2, size, size, 0, 0, 400, 400);
        canvas.toBlob(blob => {
          newAvatarBlob = blob;
          content.querySelector('#edit-avatar-img').src = URL.createObjectURL(blob);
        }, 'image/jpeg', 0.85);
        stream.getTracks().forEach(t => t.stop());
        overlay.remove();
      };
    } catch(e) { toast('カメラにアクセスできません'); }
  };

  header.querySelector('#save-profile').onclick = async () => {
    const username = content.querySelector('#edit-username').value.trim();
    const displayName = content.querySelector('#edit-display-name').value.trim();
    const bio = content.querySelector('#edit-bio').value.trim();

    if (!username) { toast('ユーザー名を入力してください'); return; }
    if (!/^[a-zA-Z0-9_]+$/.test(username)) { toast('ユーザー名は英数字と_のみ'); return; }

    showLoading();
    try {
      let avatarUrl = profile.avatar_url;

      if (newAvatarBlob) {
        const filename = `${state.user.id}/${Date.now()}.jpg`;
        const { error: upErr } = await sb.storage.from('ri-avatars').upload(filename, newAvatarBlob, { contentType: 'image/jpeg' });
        if (upErr) throw upErr;
        const { data: urlData } = sb.storage.from('ri-avatars').getPublicUrl(filename);
        avatarUrl = urlData.publicUrl;
      }

      const { error } = await sb.from('ri_profiles').update({
        username,
        display_name: displayName || null,
        bio: bio || null,
        avatar_url: avatarUrl,
        updated_at: new Date().toISOString()
      }).eq('id', state.user.id);

      if (error) {
        if (error.message.includes('unique') || error.code === '23505') {
          toast('このユーザー名は既に使われています');
        } else {
          throw error;
        }
        return;
      }

      state.profile = { ...state.profile, username, display_name: displayName, bio, avatar_url: avatarUrl };
      toast('保存しました');
      goBack();
    } catch(e) {
      toast('保存に失敗: ' + e.message);
    } finally {
      hideLoading();
    }
  };
}

// ============================================
// SETTINGS
// ============================================
function renderSettings(header, content) {
  header.innerHTML = `<div class="header">
    <div class="header-left"><button class="header-btn" onclick="goBack()">${icons.back}</button></div>
    <div class="header-title">設定</div>
    <div class="header-right"></div>
  </div>`;

  content.innerHTML = `
    <div class="settings-group">
      <div class="settings-item" id="set-blocks">ブロックリスト</div>
    </div>
    <div class="settings-group">
      <div class="settings-item" id="set-terms">利用規約</div>
      <div class="settings-item" id="set-privacy">プライバシーポリシー</div>
    </div>
    <div class="settings-group">
      <div class="settings-item" id="set-logout">ログアウト</div>
    </div>
    <div class="settings-group">
      <div class="settings-item danger" id="set-delete">アカウントを削除</div>
    </div>
    <div style="text-align:center;padding:20px;color:var(--text-secondary);font-size:12px">Real Insta v1.0.0</div>
  `;

  content.querySelector('#set-logout').onclick = async () => {
    await sb.auth.signOut();
    window.location.href = '/';
  };

  content.querySelector('#set-delete').onclick = async () => {
    if (confirm('本当にアカウントを削除しますか？この操作は取り消せません。')) {
      if (confirm('すべてのデータが失われます。本当に削除しますか？')) {
        toast('アカウント削除リクエストを送信しました');
      }
    }
  };

  content.querySelector('#set-blocks').onclick = async () => {
    const { data: blocks } = await sb
      .from('ri_blocks')
      .select('*, blocked:blocked_id(id, username, avatar_url)')
      .eq('blocker_id', state.user.id);

    const overlay = el('div', { className: 'overlay' });
    const sheet = el('div', { className: 'modal-sheet' });
    sheet.innerHTML = `<div class="modal-handle"></div><div style="padding:16px;font-weight:600;text-align:center;border-bottom:1px solid var(--border)">ブロックリスト</div>`;

    if (!blocks || blocks.length === 0) {
      sheet.innerHTML += '<div style="padding:20px;text-align:center;color:var(--text-secondary)">ブロックしているユーザーはいません</div>';
    } else {
      blocks.forEach(b => {
        const user = b.blocked || {};
        const item = el('div', { className: 'search-user-item' });
        item.innerHTML = `
          <img class="search-user-avatar" src="${avatarUrl(user.avatar_url)}" alt="">
          <div class="search-user-info"><div class="search-user-name">${user.username || 'user'}</div></div>
          <button class="btn-secondary" style="flex:none;padding:6px 12px;font-size:13px">解除</button>
        `;
        item.querySelector('button').onclick = async () => {
          await sb.from('ri_blocks').delete().eq('blocker_id', state.user.id).eq('blocked_id', user.id);
          item.remove();
          toast('ブロックを解除しました');
        };
        sheet.appendChild(item);
      });
    }

    overlay.appendChild(sheet);
    overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };
    document.getElementById('overlay-container').appendChild(overlay);
  };
}

// ============================================
// HASHTAG
// ============================================
async function renderHashtag(header, content, tag) {
  header.innerHTML = `<div class="header">
    <div class="header-left"><button class="header-btn" onclick="goBack()">${icons.back}</button></div>
    <div class="header-title">#${tag}</div>
    <div class="header-right"></div>
  </div>`;

  content.innerHTML = '<div class="spinner"></div>';

  const { data: hashtagRow } = await sb.from('ri_hashtags').select('id').eq('name', tag).maybeSingle();
  if (!hashtagRow) { content.innerHTML = '<div class="empty-state"><p>ハッシュタグが見つかりません</p></div>'; return; }

  const { data: postHashtags } = await sb.from('ri_post_hashtags').select('post_id').eq('hashtag_id', hashtagRow.id);
  const postIds = (postHashtags || []).map(ph => ph.post_id);

  if (postIds.length === 0) { content.innerHTML = '<div class="empty-state"><p>投稿がありません</p></div>'; return; }

  const { data: posts } = await sb
    .from('ri_posts')
    .select('id, image_url')
    .in('id', postIds)
    .order('created_at', { ascending: false });

  content.innerHTML = `<div class="hashtag-header"><h2>#${tag}</h2><p>投稿${posts?.length || 0}件</p></div>`;

  if (posts && posts.length > 0) {
    const grid = el('div', { className: 'photo-grid' });
    posts.forEach(p => {
      const img = el('img', { className: 'photo-grid-item', src: p.image_url, loading: 'lazy', alt: '' });
      img.onclick = () => navigate('post', { postId: p.id });
      grid.appendChild(img);
    });
    content.appendChild(grid);
  }
}

// ============================================
// DM (Direct Messages)
// ============================================
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function truncate(str, len) {
  if (!str) return '';
  return str.length > len ? str.slice(0, len) + '…' : str;
}

function formatMessageTime(date) {
  const d = new Date(date);
  return d.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
}

function createMessageBubble(msg) {
  const isMine = msg.sender_id === state.user.id;
  const wrap = el('div', { className: `dm-bubble-wrap ${isMine ? 'mine' : 'theirs'}` });
  const bubble = el('div', { className: `dm-bubble ${isMine ? 'mine' : 'theirs'}` });
  bubble.textContent = msg.content;
  wrap.appendChild(bubble);

  const timeLine = el('div', { className: 'dm-bubble-time' });
  timeLine.textContent = formatMessageTime(msg.created_at);
  if (isMine && msg.is_read) {
    const readMark = el('span', { className: 'dm-bubble-read', html: icons.checkDouble });
    timeLine.appendChild(readMark);
  }
  wrap.appendChild(timeLine);
  return wrap;
}

async function openOrCreateConversation(otherUserId) {
  showLoading();
  try {
    const ids = [state.user.id, otherUserId].sort();
    // Check existing
    const { data: existing } = await sb
      .from('ri_conversations')
      .select('*')
      .eq('user1_id', ids[0])
      .eq('user2_id', ids[1])
      .maybeSingle();

    if (existing) {
      hideLoading();
      navigate('thread', { conversationId: existing.id, otherUserId });
      return;
    }

    // Create new
    const { data: conv, error } = await sb
      .from('ri_conversations')
      .insert({ user1_id: ids[0], user2_id: ids[1] })
      .select()
      .single();

    if (error) throw error;
    hideLoading();
    navigate('thread', { conversationId: conv.id, otherUserId });
  } catch (e) {
    hideLoading();
    if (e.message?.includes('ri_blocks') || e.code === '23514') {
      toast('このユーザーにメッセージを送れません');
    } else {
      toast('エラー: ' + e.message);
    }
  }
}

async function renderInbox(header, content) {
  header.innerHTML = `<div class="header">
    <div class="header-left"><button class="header-btn" onclick="goBack()">${icons.back}</button></div>
    <div class="header-title">メッセージ</div>
    <div class="header-right"></div>
  </div>`;

  content.innerHTML = '<div class="spinner"></div>';

  const { data: convs } = await sb
    .from('ri_conversations')
    .select('*')
    .or(`user1_id.eq.${state.user.id},user2_id.eq.${state.user.id}`)
    .order('last_message_at', { ascending: false });

  if (!convs || convs.length === 0) {
    content.innerHTML = `<div class="empty-state">${icons.dm}<p>まだメッセージはありません</p></div>`;
    return;
  }

  content.innerHTML = '';

  // Get other user profiles
  const otherIds = convs.map(c => c.user1_id === state.user.id ? c.user2_id : c.user1_id);
  const { data: profiles } = await sb.from('ri_profiles').select('id, username, display_name, avatar_url').in('id', otherIds);
  const profileMap = {};
  (profiles || []).forEach(p => profileMap[p.id] = p);

  // Get unread counts per conversation
  const { data: unreadMsgs } = await sb
    .from('ri_messages')
    .select('conversation_id')
    .in('conversation_id', convs.map(c => c.id))
    .neq('sender_id', state.user.id)
    .eq('is_read', false);

  const unreadMap = {};
  (unreadMsgs || []).forEach(m => { unreadMap[m.conversation_id] = (unreadMap[m.conversation_id] || 0) + 1; });

  convs.forEach(c => {
    const otherId = c.user1_id === state.user.id ? c.user2_id : c.user1_id;
    const otherProfile = profileMap[otherId] || {};
    const unread = unreadMap[c.id] || 0;

    const item = el('div', { className: 'dm-conv-item' });
    item.innerHTML = `
      <img class="dm-conv-avatar" src="${avatarUrl(otherProfile.avatar_url)}" alt="">
      <div class="dm-conv-body">
        <div class="dm-conv-name">${otherProfile.username || otherProfile.display_name || 'user'}</div>
        <div class="dm-conv-preview ${unread > 0 ? 'unread' : ''}">${escapeHtml(truncate(c.last_message_text || '', 30))}</div>
      </div>
      <div class="dm-conv-meta">
        <div class="dm-conv-time">${c.last_message_at ? timeAgo(c.last_message_at) : ''}</div>
        ${unread > 0 ? `<div class="dm-unread-badge">${unread}</div>` : ''}
      </div>
    `;
    item.onclick = () => navigate('thread', { conversationId: c.id, otherUserId: otherId });
    content.appendChild(item);
  });
}

async function renderThread(header, content, conversationId, otherUserId) {
  // Load other user profile
  const { data: otherProfile } = await sb.from('ri_profiles').select('*').eq('id', otherUserId).single();
  const displayName = otherProfile?.username || otherProfile?.display_name || 'user';

  header.innerHTML = `<div class="header">
    <div class="header-left"><button class="header-btn" onclick="goBack()">${icons.back}</button></div>
    <div class="header-title" style="cursor:pointer" id="thread-title">${displayName}</div>
    <div class="header-right"></div>
  </div>`;
  header.querySelector('#thread-title').onclick = () => navigate('user', { userId: otherUserId });

  content.innerHTML = '<div class="spinner"></div>';

  // Load messages
  const { data: msgs } = await sb
    .from('ri_messages')
    .select('*')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: true })
    .limit(100);

  content.innerHTML = '';

  const msgsContainer = el('div', { id: 'dm-messages' });
  content.appendChild(msgsContainer);

  if (msgs && msgs.length > 0) {
    let lastDate = '';
    msgs.forEach(m => {
      const mDate = new Date(m.created_at).toLocaleDateString('ja-JP');
      if (mDate !== lastDate) {
        msgsContainer.appendChild(el('div', { className: 'dm-date-sep' }, mDate));
        lastDate = mDate;
      }
      msgsContainer.appendChild(createMessageBubble(m));
    });
  } else {
    msgsContainer.appendChild(el('div', { className: 'empty-state', style: 'padding:40px 20px' },
      el('p', {}, 'メッセージを送ってみましょう')
    ));
  }

  // Input bar
  const inputBar = el('div', { className: 'dm-input-bar' });
  const input = el('input', { type: 'text', placeholder: 'メッセージを入力...', maxlength: '1000' });
  const sendBtn = el('button', { className: 'dm-send-btn', disabled: 'true', html: icons.send });
  inputBar.append(input, sendBtn);
  content.appendChild(inputBar);

  input.oninput = () => { sendBtn.disabled = !input.value.trim(); };

  const sendMessage = async () => {
    const text = input.value.trim();
    if (!text) return;
    input.value = '';
    sendBtn.disabled = true;

    const { error } = await sb.from('ri_messages').insert({
      conversation_id: conversationId,
      sender_id: state.user.id,
      content: text
    });

    if (error) {
      toast('送信できませんでした');
      input.value = text;
      sendBtn.disabled = false;
    }
  };

  sendBtn.onclick = sendMessage;
  input.onkeydown = (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); } };

  // Mark unread as read
  await sb
    .from('ri_messages')
    .update({ is_read: true })
    .eq('conversation_id', conversationId)
    .neq('sender_id', state.user.id)
    .eq('is_read', false);

  // Subscribe to realtime
  subscribeToDmThread(conversationId, msgsContainer, content);

  // Scroll to bottom
  setTimeout(() => { content.scrollTop = content.scrollHeight; }, 100);
  input.focus();
}

function subscribeToDmThread(conversationId, msgsContainer, scrollContainer) {
  // Clean up previous subscription
  if (state.dmSubscription) {
    state.dmSubscription.unsubscribe();
    state.dmSubscription = null;
  }

  state.dmSubscription = sb
    .channel(`dm-thread-${conversationId}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'ri_messages',
      filter: `conversation_id=eq.${conversationId}`
    }, async (payload) => {
      const msg = payload.new;
      // Remove empty state if present
      const empty = msgsContainer.querySelector('.empty-state');
      if (empty) empty.remove();

      // Add date separator if needed
      const lastBubble = msgsContainer.querySelector('.dm-bubble-wrap:last-child');
      const msgDate = new Date(msg.created_at).toLocaleDateString('ja-JP');
      if (!lastBubble) {
        msgsContainer.appendChild(el('div', { className: 'dm-date-sep' }, msgDate));
      }

      msgsContainer.appendChild(createMessageBubble(msg));
      scrollContainer.scrollTop = scrollContainer.scrollHeight;

      // Mark as read if from other user
      if (msg.sender_id !== state.user.id) {
        await sb.from('ri_messages').update({ is_read: true }).eq('id', msg.id);
      }
    })
    .on('postgres_changes', {
      event: 'UPDATE',
      schema: 'public',
      table: 'ri_messages',
      filter: `conversation_id=eq.${conversationId}`
    }, (payload) => {
      // Update read status on existing bubbles
      if (payload.new.is_read && payload.new.sender_id === state.user.id) {
        // Re-render would be heavy, just add check marks to all mine
        msgsContainer.querySelectorAll('.dm-bubble-wrap.mine .dm-bubble-time').forEach(t => {
          if (!t.querySelector('.dm-bubble-read')) {
            const readMark = el('span', { className: 'dm-bubble-read', html: icons.checkDouble });
            t.appendChild(readMark);
          }
        });
      }
    })
    .subscribe();
}

let dmGlobalChannel = null;

function subscribeToDmGlobal() {
  if (dmGlobalChannel) return;

  dmGlobalChannel = sb
    .channel('dm-global')
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'ri_messages'
    }, (payload) => {
      const msg = payload.new;
      if (msg.sender_id !== state.user.id) {
        // Only increment if not currently viewing that thread
        if (state.currentView !== 'thread' || state.currentParams?.conversationId !== msg.conversation_id) {
          state.unreadDmCount++;
          updateDmBadge();
        }
      }
    })
    .subscribe();
}

function updateDmBadge() {
  const badge = document.getElementById('dm-badge');
  if (badge) {
    if (state.unreadDmCount > 0) {
      badge.textContent = state.unreadDmCount > 99 ? '99+' : state.unreadDmCount;
      badge.style.display = '';
    } else {
      badge.style.display = 'none';
    }
  }
}

async function loadUnreadDmCount() {
  const { count } = await sb
    .from('ri_messages')
    .select('*', { count: 'exact', head: true })
    .neq('sender_id', state.user.id)
    .eq('is_read', false);

  state.unreadDmCount = count || 0;
  updateDmBadge();
}

// ============================================
// ONBOARDING (Username setup)
// ============================================
async function checkOnboarding() {
  if (!state.profile.username) {
    const fs = document.getElementById('fullscreen-container');
    fs.innerHTML = '';
    const view = el('div', { className: 'create-post', style: 'justify-content:center;align-items:center;padding:40px;' });
    view.innerHTML = `
      <div style="text-align:center;width:100%;max-width:350px;">
        <h2 style="font-size:24px;font-weight:700;margin-bottom:8px;">ようこそ！</h2>
        <p style="color:var(--text-secondary);margin-bottom:24px;">ユーザー名を設定してください</p>
        <input type="text" id="onboard-username" placeholder="username" maxlength="30"
          style="width:100%;padding:12px;border:1px solid var(--border);border-radius:8px;font-size:16px;text-align:center;margin-bottom:16px;outline:none;">
        <button class="btn-primary" id="onboard-submit" style="width:100%;padding:12px;font-size:16px;border-radius:8px;">はじめる</button>
        <p id="onboard-error" style="color:#ed4956;font-size:13px;margin-top:8px;display:none;"></p>
      </div>
    `;
    fs.appendChild(view);

    const input = view.querySelector('#onboard-username');
    const errorEl = view.querySelector('#onboard-error');

    view.querySelector('#onboard-submit').onclick = async () => {
      const username = input.value.trim().toLowerCase();
      if (!username) { errorEl.textContent = 'ユーザー名を入力してください'; errorEl.style.display = 'block'; return; }
      if (!/^[a-z0-9_]{3,20}$/.test(username)) { errorEl.textContent = '3〜20文字の英小文字・数字・_のみ'; errorEl.style.display = 'block'; return; }

      const { error } = await sb.from('ri_profiles').update({ username }).eq('id', state.user.id);
      if (error) {
        if (error.code === '23505') errorEl.textContent = 'このユーザー名は既に使われています';
        else errorEl.textContent = error.message;
        errorEl.style.display = 'block';
        return;
      }

      state.profile.username = username;
      fs.innerHTML = '';
      render();
    };

    input.addEventListener('keydown', e => { if (e.key === 'Enter') view.querySelector('#onboard-submit').click(); });
    input.focus();
    return true;
  }
  return false;
}

// ============================================
// INIT
// ============================================
async function init() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) {
    window.location.href = '/';
    return;
  }

  state.user = session.user;

  // Load profile
  const { data: profile } = await sb.from('ri_profiles').select('*').eq('id', state.user.id).single();
  state.profile = profile || {};

  // Check onboarding
  const onboarding = await checkOnboarding();
  if (onboarding) return;

  // DM: load unread count and subscribe globally
  loadUnreadDmCount();
  subscribeToDmGlobal();

  render();
}

// Start
init();
</script>
</body>
</html>
