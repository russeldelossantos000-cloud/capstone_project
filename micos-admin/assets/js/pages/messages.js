/**
 * pages/messages.js — Real-time admin messaging via Firestore (Modular SDK)
 *
 * IMPORTANT: index.html must initialise Firebase and expose window.__db
 * using the modular SDK (already done in your index.html).
 *
 * Root cause of previous failure:
 *   db().collection() / db().batch() / ref.doc() are COMPAT SDK methods.
 *   window.__db comes from getFirestore() which is the MODULAR SDK —
 *   those methods simply don't exist on it, causing a silent crash.
 *   All Firestore operations must use the imported modular functions below.
 */

// ── Import all Firestore functions we need upfront ────────────────────────────
// We do a single top-level dynamic import so every function is available
// to both pageMessages and openAdminThread without repeating imports.
let _fs = null; // cached module

async function _firestore() {
  if (_fs) return _fs;
  _fs = await import('https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js');
  return _fs;
}

function db() { return window.__db; }

// ── Modular document / collection references ──────────────────────────────────
async function convRef(userId) {
  const { doc, collection } = await _firestore();
  return doc(collection(db(), 'conversations'), `user_${userId}`);
}

async function messagesCol(userId) {
  const { collection, doc } = await _firestore();
  const conv = doc(collection(db(), 'conversations'), `user_${userId}`);
  return collection(conv, 'messages');
}

// ── Active listeners — unsubscribe when navigating away ───────────────────────
let _inboxUnsub  = null;
let _threadUnsub = null;

function cleanupListeners() {
  if (_inboxUnsub)  { _inboxUnsub();  _inboxUnsub  = null; }
  if (_threadUnsub) { _threadUnsub(); _threadUnsub = null; }
}

// ══════════════════════════════════════════════════════════════════════════════
// INBOX PAGE
// ══════════════════════════════════════════════════════════════════════════════

async function pageMessages(container) {
  cleanupListeners();

  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left">
        <h2>Messages</h2>
        <p></p>
      </div>
    </div>
    <div class="page-body">
      <div class="table-card">
        <div class="table-toolbar">
          <span class="table-title">Inbox</span>
          <input type="search" class="search-input" id="msg-search"
            placeholder="Search customer…" />
          <span style="display:inline-flex;align-items:center;gap:6px;
            font-size:12px;color:#22c55e">
            <span style="width:8px;height:8px;background:#22c55e;border-radius:50%;
              display:inline-block"></span>
            Live
          </span>
        </div>
        <div id="msg-list">${spinner()}</div>
      </div>
    </div>`;

  document.getElementById('msg-search').addEventListener('input', () => {
    const q = document.getElementById('msg-search').value.toLowerCase();
    document.querySelectorAll('.msg-row').forEach(row => {
      row.style.display = row.dataset.name.toLowerCase().includes(q) ? '' : 'none';
    });
  });

  try {
    const { collection, query, orderBy, onSnapshot, doc } = await _firestore();

    const q = query(
      collection(db(), 'conversations'),
      orderBy('last_timestamp', 'desc')
    );

    _inboxUnsub = onSnapshot(q, (snap) => {
      const list = document.getElementById('msg-list');
      if (!list) return;

      if (snap.empty) {
        list.innerHTML = `<p class="table-empty">No conversations yet.</p>`;
        return;
      }

      list.innerHTML = snap.docs.map(docSnap => {
        const d        = docSnap.data();
        const userId   = d.user_id;
        const name     = d.user_name    || `User #${userId}`;
        const preview  = d.last_message || '';
        const unread   = d.unread_admin || 0;
        const ts       = d.last_timestamp?.toDate();
        const initials = name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();

        return `
          <div class="msg-row ${unread > 0 ? 'unread' : ''}"
               data-name="${name.replace(/"/g, '&quot;')}"
               onclick="openAdminThread(${userId}, '${name.replace(/'/g, "\\'")}')">
            <div class="msg-avatar">${initials}</div>
            <div class="msg-info">
              <div class="msg-name">${name}</div>
              <div class="msg-preview">${preview}</div>
            </div>
            <div style="display:flex;flex-direction:column;align-items:flex-end;gap:6px">
              <span class="msg-time">${ts ? fmtDateTime(ts.toISOString()) : ''}</span>
              ${unread > 0
                ? `<span style="background:var(--accent);color:#fff;border-radius:10px;
                     padding:2px 8px;font-size:11px;font-weight:700">${unread}</span>`
                : ''}
            </div>
          </div>`;
      }).join('');

    }, (err) => {
      // onSnapshot error handler — shows in the list instead of silently failing
      const list = document.getElementById('msg-list');
      if (list) {
        list.innerHTML = `<div class="alert alert-error" style="margin:16px">
          Firestore error: ${err.message}
        </div>`;
      }
    });

  } catch (err) {
    document.getElementById('msg-list').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// THREAD / CHAT VIEW (inside modal)
// ══════════════════════════════════════════════════════════════════════════════

async function openAdminThread(userId, name) {
  if (_threadUnsub) { _threadUnsub(); _threadUnsub = null; }

  Modal.open({
    title: `Chat with ${name}`,
    large: true,
    body: spinner(),
    footer: '',
  });

  try {
    const {
      collection, doc, query, orderBy, onSnapshot,
      setDoc, addDoc, getDocs, where,
      serverTimestamp, writeBatch, increment,
    } = await _firestore();

    // ── Modular references ───────────────────────────────────────────────────
    const convDocRef = doc(collection(db(), 'conversations'), `user_${userId}`);
    const msgsCol    = collection(convDocRef, 'messages');

    // Mark admin unread counter as 0
    await setDoc(convDocRef, { unread_admin: 0 }, { merge: true });

    // Mark individual user messages as read
    const unreadQ    = query(msgsCol, where('sender', '==', 'user'), where('is_read', '==', false));
    const unreadSnap = await getDocs(unreadQ);
    if (!unreadSnap.empty) {
      const batch = writeBatch(db());
      unreadSnap.forEach(d => batch.update(d.ref, { is_read: true }));
      await batch.commit();
    }

    // Render thread shell
    document.getElementById('modal-body').innerHTML = `
      <div id="thread-wrap"
           style="height:380px;overflow-y:auto;display:flex;flex-direction:column;
                  gap:8px;padding:4px 0 8px">
        <div style="text-align:center;color:var(--muted);font-size:12px;padding:20px">
          Loading messages…
        </div>
      </div>`;

    document.getElementById('modal-footer').innerHTML = `
  <div style="display:flex;flex-direction:column;gap:8px;width:100%">
    <div id="chat-image-preview" style="display:none;position:relative;width:fit-content">
      <img id="chat-preview-img" style="max-height:80px;border-radius:8px;border:1px solid var(--border)" />
      <button onclick="removeChatImage()"
        style="position:absolute;top:-6px;right:-6px;width:20px;height:20px;border-radius:50%;
               background:var(--danger);color:#fff;border:none;cursor:pointer;font-size:12px;
               display:flex;align-items:center;justify-content:center;line-height:1">✕</button>
    </div>
    <div style="display:flex;gap:8px;width:100%">
      <input type="file" id="chat-image-input" accept="image/jpeg,image/png,image/webp,image/gif" style="display:none" onchange="handleChatImageSelect(this)" />
      <button onclick="document.getElementById('chat-image-input').click()"
        style="align-self:flex-end;height:42px;width:42px;border-radius:8px;background:var(--surface2);
               border:1px solid var(--border);color:var(--muted);cursor:pointer;font-size:18px;flex-shrink:0"
        title="Attach photo">
        📎
      </button>
      <textarea id="admin-reply-input" rows="2"
        placeholder="Type a reply… (Ctrl+Enter to send)"
        style="flex:1;resize:none;border-radius:8px;padding:10px 14px;
               background:var(--surface2);border:1px solid var(--border);
               color:var(--text);font-size:13px;font-family:inherit"></textarea>
      <button class="btn btn-primary" id="admin-send-btn"
        style="align-self:flex-end;height:42px;padding:0 20px">
        Send
      </button>
    </div>
  </div>`;

   let _chatSelectedFile = null;

window.handleChatImageSelect = function(input) {
  const file = input.files[0];
  if (!file) return;
  _chatSelectedFile = file;

  const reader = new FileReader();
  reader.onload = e => {
    document.getElementById('chat-preview-img').src = e.target.result;
    document.getElementById('chat-image-preview').style.display = 'block';
  };
  reader.readAsDataURL(file);
}

window.removeChatImage = function() {
  _chatSelectedFile = null;
  document.getElementById('chat-image-preview').style.display = 'none';
  document.getElementById('chat-image-input').value = '';
}

async function uploadChatImage(file) {
  const formData = new FormData();
  formData.append('image', file);
  const token = localStorage.getItem('admin_token');

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', API.BASE_URL + '/upload/chat-image');
    xhr.setRequestHeader('Authorization', `Bearer ${token}`);
    xhr.onload = () => {
      try {
        const res = JSON.parse(xhr.responseText);
        if (xhr.status >= 200 && xhr.status < 300) resolve(res.image_url);
        else reject(new Error(res.error || 'Upload failed'));
      } catch { reject(new Error('Upload failed')); }
    };
    xhr.onerror = () => reject(new Error('Network error during upload'));
    xhr.send(formData);
  });
}

    // ── Real-time thread listener ─────────────────────────────────────────────
    const msgQ = query(msgsCol, orderBy('timestamp', 'asc'));

    _threadUnsub = onSnapshot(msgQ, (snap) => {
      const wrap = document.getElementById('thread-wrap');
      if (!wrap) return;

      if (snap.empty) {
        wrap.innerHTML = `
          <div style="text-align:center;color:var(--muted);font-size:13px;padding:40px 0">
            No messages yet. Send the first one!
          </div>`;
        return;
      }

      wrap.innerHTML = snap.docs.map(d => {
  const msg     = d.data();
  const isAdmin = msg.sender === 'admin';
  const text    = msg.text    || '';
  const imgUrl  = msg.image_url || null;
  const ts      = msg.timestamp?.toDate();
  const timeStr = ts ? fmtDateTime(ts.toISOString()) : '';
  const isRead  = msg.is_read === true;
  const fullImgUrl = imgUrl ? API.imgUrl(imgUrl) : null;

  return `
    <div style="display:flex;gap:8px;align-items:flex-end;
      flex-direction:${isAdmin ? 'row-reverse' : 'row'}">
      <div class="msg-avatar"
           style="width:28px;height:28px;font-size:11px;flex-shrink:0;
           ${isAdmin ? 'background:var(--accent);color:#fff' : ''}">
        ${isAdmin ? 'A' : (msg.sender_name?.[0]?.toUpperCase() || 'U')}
      </div>
      <div style="max-width:70%">
        <div style="
          background:${isAdmin ? 'var(--accent)' : 'var(--surface2)'};
          color:${isAdmin ? '#fff' : 'var(--text)'};
          border-radius:${isAdmin ? '12px 4px 12px 12px' : '4px 12px 12px 12px'};
          padding:${imgUrl ? '6px' : '10px 14px'};font-size:13px;line-height:1.5;
          border:1px solid ${isAdmin ? 'var(--accent)' : 'var(--border)'}">
          ${imgUrl ? `
            <img src="${fullImgUrl}" onclick="window.open('${fullImgUrl}','_blank')"
                 style="max-width:220px;max-height:220px;border-radius:8px;cursor:pointer;display:block;
                 ${text ? 'margin-bottom:6px' : ''}"
                 onerror="this.style.display='none'" />` : ''}
          ${text ? `<div style="${imgUrl ? 'padding:0 8px 4px' : ''}">${text}</div>` : ''}
        </div>
        <div style="font-size:10px;color:var(--muted);margin-top:3px;
          text-align:${isAdmin ? 'right' : 'left'}">
          ${timeStr}
          ${isAdmin ? (isRead ? ' ✓✓' : ' ✓') : ''}
        </div>
      </div>
    </div>`;
}).join('');

      wrap.scrollTop = wrap.scrollHeight;
    });

    // ── Send handler ──────────────────────────────────────────────────────────
   
    async function sendAdminReply() {
  const input = document.getElementById('admin-reply-input');
  const btn   = document.getElementById('admin-send-btn');
  const text  = input?.value.trim();

  if (!text && !_chatSelectedFile) return;

  btn.disabled    = true;
  btn.textContent = '…';

  const originalText = text;
  input.value = '';

  try {
    let imageUrl = null;
    if (_chatSelectedFile) {
      btn.textContent = 'Uploading…';
      imageUrl = await uploadChatImage(_chatSelectedFile);
    }

    const batch = writeBatch(db());

    const newMsgRef = doc(msgsCol);
    const msgData = {
      sender:      'admin',
      sender_name: 'Admin',
      text:        originalText || '',
      timestamp:   serverTimestamp(),
      is_read:     false,
    };
    if (imageUrl) msgData.image_url = imageUrl;

    batch.set(newMsgRef, msgData);

    const lastMsgPreview = imageUrl ? (originalText ? originalText : '📷 Photo') : originalText;
    batch.set(convDocRef, {
      last_message:   lastMsgPreview,
      last_timestamp: serverTimestamp(),
      unread_user:    increment(1),
      unread_admin:   0,
    }, { merge: true });

    await batch.commit();

    removeChatImage();
    toast('Reply sent!', 'success');

  } catch (err) {
    toast(err.message, 'error');
    if (input) input.value = originalText;
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'Send'; }
  }
}

    document.getElementById('admin-send-btn')
      .addEventListener('click', sendAdminReply);

    document.getElementById('admin-reply-input')
      .addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
          e.preventDefault();
          sendAdminReply();
        }
      });

  } catch (err) {
    document.getElementById('modal-body').innerHTML =
      `<div class="alert alert-error">${err.message}</div>`;
  }
}