/**
 * app.js — Bootstrap & global event handlers
 */
document.addEventListener('DOMContentLoaded', () => {

  // ── Global notification bell badge ───────────────────────────────────────────
async function startGlobalNotifBadge() {
  try {
    const { collection, query, where, onSnapshot } = await import(
      'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js'
    );
    const db = window.__db;
    if (!db) return;

    const q = query(collection(db, 'admin_notifications'), where('read', '==', false));

    onSnapshot(q, snap => {
      const count = snap.size;
      const badge = document.getElementById('nav-notif-badge');
      if (badge) {
        badge.textContent = count > 99 ? '99+' : count;
        badge.style.display = count > 0 ? 'inline-block' : 'none';
      }

      // Also track unread messages separately for dashboard
      const messageCount = snap.docs.filter(d => d.data().type === 'new_message').length;
      window._dashUnreadMsgCount = messageCount;
    });
  } catch (_) {}
}


// ── Global new-message detector — writes admin_notifications on incoming messages ──
let _globalUnreadCounts = {};

async function startGlobalMessageWatcher() {
  try {
    const { collection, query, orderBy, onSnapshot, addDoc } = await import(
      'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js'
    );
    const db = window.__db;
    if (!db) return;

    const q = query(collection(db, 'conversations'), orderBy('last_timestamp', 'desc'));

    onSnapshot(q, (snap) => {
      snap.docs.forEach(docSnap => {
        const d = docSnap.data();
        const userId = d.user_id;
        const currentUnread  = d.unread_admin || 0;
        const previousUnread = _globalUnreadCounts[userId] ?? currentUnread;

        if (currentUnread > previousUnread) {
          addDoc(collection(db, 'admin_notifications'), {
            type:       'new_message',
            category:   'messages',
            message:    `New message from ${d.user_name || `User #${userId}`}: ${(d.last_message || '').slice(0, 60)}${(d.last_message || '').length > 60 ? '…' : ''}`,
            user_id:    userId,
            read:       false,
            created_at: new Date().toISOString(),
          }).catch(() => {});
        }
        _globalUnreadCounts[userId] = currentUnread;
      });
    });
  } catch (_) {}
}

   if (Auth.isLoggedIn()) {
   startGlobalNotifBadge();
   startGlobalMessageWatcher();
  }
  // ── Login form ──────────────────────────────────────────────────────────────
  document.getElementById('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const btn      = document.getElementById('login-btn');
    const errEl    = document.getElementById('login-error');
    const username = document.getElementById('login-username').value.trim();
    const password = document.getElementById('login-password').value;

    errEl.classList.add('hidden');
    btn.textContent = 'Signing in…';
    btn.disabled    = true;

    try {
      const res = await API.adminLogin({ username, password });
      Auth.save(res.token, res.admin);
      Router.resolve();
      startGlobalNotifBadge();
      startGlobalMessageWatcher();
    } catch (err) {
      errEl.textContent = err.message || 'Invalid credentials.';
      errEl.classList.remove('hidden');
    } finally {
      btn.textContent = 'Sign In';
      btn.disabled    = false;
    }
  });

  // ── Logout ──────────────────────────────────────────────────────────────────
  document.getElementById('logout-btn').addEventListener('click', () => {
    Auth.clear();
    Router.showLogin();
    window.location.hash = '#/dashboard';
  });

  // ── Boot ────────────────────────────────────────────────────────────────────
  if (!Auth.isLoggedIn()) {
    document.getElementById('login-screen').classList.remove('hidden');
  } else {
    Router.resolve();
  }
});

// Temporary placeholders — replaced in upcoming fixes
async function pageSettings(container) {
  container.innerHTML = `<div class="page-body"><p style="padding:40px;color:var(--muted)">Settings page coming soon.</p></div>`;
}