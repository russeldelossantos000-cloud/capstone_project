/**
 * pages/notifications.js
 * Organized notification center — Orders / Inventory / Customers / Messages
 */

let _notifications = [];
let _notifFilter = '';
let _notifReadFilter = '';

async function pageNotifications(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left">
        <h2>Notifications</h2>
        <p>System events across orders, inventory, customers, and messages</p>
      </div>
      <button class="btn btn-secondary" id="mark-all-read-btn">Mark all as read</button>
    </div>
    <div class="page-body">
      <div class="table-card">
        <div class="table-toolbar">
          <select id="notif-category-filter" style="width:150px">
            <option value="">All Categories</option>
            <option value="orders">Orders</option>
            <option value="inventory">Inventory</option>
            <option value="customers">Customers</option>
            <option value="messages">Messages</option>
          </select>
          <select id="notif-read-filter" style="width:130px">
            <option value="">All</option>
            <option value="unread">Unread</option>
            <option value="read">Read</option>
          </select>
        </div>
        <div id="notif-list">${spinner()}</div>
      </div>
    </div>`;

  document.getElementById('notif-category-filter').addEventListener('change', e => {
    _notifFilter = e.target.value; renderNotifList();
  });
  document.getElementById('notif-read-filter').addEventListener('change', e => {
    _notifReadFilter = e.target.value; renderNotifList();
  });
  document.getElementById('mark-all-read-btn').addEventListener('click', markAllNotifsRead);

  await loadNotifications();
  _startNotifListener();
}

async function loadNotifications() {
  try {
    const { collection, query, orderBy, getDocs } = await import(
      'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js'
    );
    const db = window.__db;
    const q  = query(collection(db, 'admin_notifications'), orderBy('created_at', 'desc'));
    const snap = await getDocs(q);

    _notifications = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    renderNotifList();
  } catch (err) {
    document.getElementById('notif-list').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

const NOTIF_ICONS = {
  new_order:    { icon: '🛒', color: 'var(--accent)', link: '#/orders' },
  gcash_receipt:{ icon: '💰', color: 'var(--warning)', link: '#/orders' },
  low_stock:    { icon: '📦', color: 'var(--danger)',  link: '#/inventory' },
  new_message:  { icon: '💬', color: 'var(--info)',    link: '#/messages' },
  new_customer: { icon: '👤', color: 'var(--success)', link: '#/customers' },
  new_review:   { icon: '⭐', color: 'var(--success)', link: '#/customers' },
};

function renderNotifList() {
  let filtered = _notifications.filter(n =>
    (!_notifFilter     || n.category === _notifFilter) &&
    (!_notifReadFilter ||
      (_notifReadFilter === 'unread' && n.read === false) ||
      (_notifReadFilter === 'read'   && n.read === true))
  );

  if (filtered.length === 0) {
    document.getElementById('notif-list').innerHTML = `<p class="table-empty">No notifications found.</p>`;
    return;
  }

  document.getElementById('notif-list').innerHTML = filtered.map(n => {
    const meta = NOTIF_ICONS[n.type] || { icon: '🔔', color: 'var(--muted)', link: '#/dashboard' };
    const timeAgo = _timeAgo(n.created_at);
    return `
      <div onclick="openNotification('${n.id}', '${meta.link}')"
        style="display:flex;align-items:flex-start;gap:12px;padding:14px 16px;
        cursor:pointer;border-bottom:1px solid var(--border);
        background:${n.read ? 'transparent' : 'rgba(249,115,22,.04)'}">
        <div style="width:32px;height:32px;border-radius:50%;background:${meta.color}22;
          display:flex;align-items:center;justify-content:center;font-size:16px;flex-shrink:0">
          ${meta.icon}
        </div>
        <div style="flex:1">
          <div style="font-size:13px;color:var(--text);${!n.read ? 'font-weight:600' : ''}">${n.message}</div>
          <div style="font-size:11px;color:var(--muted);margin-top:3px">${timeAgo}</div>
        </div>
        ${!n.read ? `<span style="width:8px;height:8px;border-radius:50%;background:var(--accent);margin-top:6px;flex-shrink:0"></span>` : ''}
      </div>`;
  }).join('');
}

function _timeAgo(isoString) {
  if (!isoString) return '';
  const diff = (Date.now() - new Date(isoString).getTime()) / 1000;
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff/60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff/3600)} hr ago`;
  return `${Math.floor(diff/86400)}d ago`;
}

async function openNotification(docId, link) {
  try {
    const { doc, updateDoc } = await import(
      'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js'
    );
    const db = window.__db;
    await updateDoc(doc(db, 'admin_notifications', docId), { read: true });
  } catch (_) {}
  window.location.hash = link;
}

async function markAllNotifsRead() {
  try {
    const { collection, getDocs, doc, writeBatch, query, where } = await import(
      'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js'
    );
    const db = window.__db;
    const q  = query(collection(db, 'admin_notifications'), where('read', '==', false));
    const snap = await getDocs(q);

    const batch = writeBatch(db);
    snap.docs.forEach(d => batch.update(d.ref, { read: true }));
    await batch.commit();

    toast('All notifications marked as read.', 'success');
    await loadNotifications();
  } catch (err) { toast(err.message, 'error'); }
}

// ── Real-time listener for the page ────────────────────────────────────────────
let _notifPageListener = null;

async function _startNotifListener() {
  if (_notifPageListener) { _notifPageListener(); _notifPageListener = null; }
  try {
    const { collection, query, orderBy, onSnapshot } = await import(
      'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js'
    );
    const db = window.__db;
    const q  = query(collection(db, 'admin_notifications'), orderBy('created_at', 'desc'));

    _notifPageListener = onSnapshot(q, snap => {
      _notifications = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      renderNotifList();
    });
  } catch (_) {}
}