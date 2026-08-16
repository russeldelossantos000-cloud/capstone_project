/**
 * pages/dashboard.js — Full rewrite
 * Action-based dashboard: Critical Alerts → Today's Snapshot → Pending Actions → Low Stock → Activity Feed
 */

let _dashListener = null;

async function pageDashboard(container) {
  const now = new Date();
  const dateStr = now.toLocaleDateString('en-PH', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
  const hour = now.getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left">
        <h2>${greeting}, ${Auth.getAdmin()?.name || 'Admin'} 👋</h2>
        <p>${dateStr}</p>
      </div>
    </div>
    <div class="page-body" style="display:flex;flex-direction:column;gap:20px">

      <!-- Row 1: Critical Alerts -->
      <div id="dash-alerts" class="stat-grid">${spinner()}</div>

      <!-- Row 2: Today's Snapshot -->
      <div>
        <p class="form-section-label">TODAY'S SNAPSHOT</p>
        <div id="dash-today" class="stat-grid">${spinner()}</div>
      </div>

     <!-- Row 3: Action Tables -->
<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
  <div class="table-card">
    <div class="table-toolbar">
      <span class="table-title">⏳ Pending Orders</span>
    </div>
    <div id="dash-pending-orders">${spinner()}</div>
  </div>
  <div class="table-card">
    <div class="table-toolbar">
      <span class="table-title">💰 Unpaid Orders</span>
    </div>
    <div id="dash-unpaid-orders">${spinner()}</div>
  </div>
</div>

      <!-- Row 4: Low Stock -->
      <div class="table-card">
        <div class="table-toolbar">
          <span class="table-title">🔴 Low Stock Alerts</span>
        </div>
        <div id="dash-low-stock">${spinner()}</div>
      </div>

      <!-- Row 5: Recent Activity -->
      <div class="table-card">
        <div class="table-toolbar">
          <span class="table-title">📋 Recent Activity</span>
        </div>
        <div id="dash-activity">${spinner()}</div>
      </div>

    </div>`;

  await loadDashboard();
  _startDashListener();
}

async function loadDashboard() {
  try {
    const [stats, orders, inventory, logs] = await Promise.all([
      API.getDashboard(),
      API.getAdminOrders(),
      API.getInventory(),
      API.getInventoryLogs(),
    ]);

    renderAlerts(stats, orders, inventory);
    renderTodaySnapshot(orders, logs);
    renderPendingOrdersTable(orders);
    renderUnpaidOrdersTable(orders);
    renderLowStockTable(inventory);
    renderActivityFeed(orders, logs);

  } catch (err) {
    document.getElementById('dash-alerts').innerHTML =
      `<div class="alert alert-error">Failed to load dashboard: ${err.message}</div>`;
  }
}

// ── Row 1: Critical Alerts ─────────────────────────────────────────────────────
function renderAlerts(stats, orders, inventory) {
  const pendingCount   = orders.filter(o => o.status === 'pending').length;
  const unpaidCount    = orders.filter(o => o.payment_status === 'unpaid' && o.status !== 'cancelled').length;
  const lowStockCount  = inventory.filter(p => p.stock_status === 'low' || p.stock_status === 'out_of_stock').length;
  const unreadMsgs     = window._dashUnreadMsgCount || 0;

  document.getElementById('dash-alerts').innerHTML = `
    ${alertCard('Low Stock Items', lowStockCount, lowStockCount > 0 ? 'danger' : '', '#/inventory')}
    ${alertCard('Pending Orders', pendingCount, pendingCount > 0 ? 'warning' : '', '#/orders')}
    ${alertCard('Unpaid Orders', unpaidCount, unpaidCount > 0 ? 'warning' : '', '#/orders')}
    ${alertCard('Unread Messages', unreadMsgs, unreadMsgs > 0 ? 'info' : '', '#/messages')}
  `;
}
function alertCard(label, value, accent, link) {
  const isUrgent = accent !== '';
  return `
    <a href="${link}" class="stat-card" style="text-decoration:none;display:block;cursor:pointer;
       ${isUrgent ? 'border-color:var(--' + accent + ')' : ''}">
      <div class="stat-label">${label}</div>
      <div class="stat-value ${accent}">${value}</div>
      ${isUrgent ? `<div style="font-size:10px;color:var(--${accent});margin-top:4px">→ Needs attention</div>`
                 : `<div style="font-size:10px;color:var(--muted);margin-top:4px">All clear</div>`}
    </a>`;
}

// ── Row 2: Today's Snapshot ───────────────────────────────────────────────────
function renderTodaySnapshot(orders, logs) {
  const today = new Date().toISOString().slice(0, 10);

  const ordersToday = orders.filter(o => (o.created_at || '').slice(0, 10) === today);
  const itemsSoldToday = logs.filter(l =>
    (l.created_at || '').slice(0, 10) === today && l.change_type === 'OUT'
  ).reduce((s, l) => s + parseInt(l.quantity || 0), 0);

  const walkinToday = logs.filter(l =>
    (l.created_at || '').slice(0, 10) === today && l.transaction_type === 'walk_in_sale'
  ).length;

  document.getElementById('dash-today').innerHTML = `
    ${statCard('Orders Today', ordersToday.length, '')}
    ${statCard('Walk-in Sales Today', walkinToday, '')}
    ${statCard('Items Sold Today', itemsSoldToday, '')}
  `;
}

function statCard(label, value, accent) {
  return `
    <div class="stat-card">
      <div class="stat-label">${label}</div>
      <div class="stat-value ${accent}">${value}</div>
    </div>`;
}

// ── Row 3: Pending Orders Table ────────────────────────────────────────────────
function renderPendingOrdersTable(orders) {
  const pending = orders.filter(o => o.status === 'pending').slice(0, 5);

  document.getElementById('dash-pending-orders').innerHTML = pending.length === 0
    ? `<p class="table-empty" style="color:var(--success)">✓ No pending orders.</p>`
    : `<table>
        <thead><tr><th>Reference</th><th>Customer</th><th>Type</th><th>Amount</th><th></th></tr></thead>
        <tbody>
          ${pending.map(o => `
            <tr>
              <td class="mono text-accent" style="font-size:11px">${o.reference_number}</td>
              <td class="fw-600">${o.customer_name}</td>
              <td><span class="badge ${o.delivery_type === 'pickup' ? 'badge-default' : 'badge-processing'}">
                ${o.delivery_type === 'pickup' ? '🏪' : '🚴'} ${o.delivery_type}
              </span></td>
              <td class="mono">${peso(o.total_amount)}</td>
              <td><a href="#/orders" class="btn btn-ghost btn-sm">Process</a></td>
            </tr>`).join('')}
        </tbody>
      </table>`;
}

// ── Row 3: Unpaid Orders Table ─────────────────────────────────────────────────
function renderUnpaidOrdersTable(orders) {
  const unpaid = orders
    .filter(o => o.payment_status === 'unpaid' && o.status !== 'cancelled')
    .slice(0, 5);

  document.getElementById('dash-unpaid-orders').innerHTML = unpaid.length === 0
    ? `<p class="table-empty" style="color:var(--success)">✓ No unpaid orders.</p>`
    : `<table>
        <thead><tr><th>Reference</th><th>Customer</th><th>Amount</th><th></th></tr></thead>
        <tbody>
          ${unpaid.map(o => `
            <tr>
              <td class="mono text-accent" style="font-size:11px">${o.reference_number}</td>
              <td class="fw-600">${o.customer_name}</td>
              <td class="mono">${peso(o.total_amount)}</td>
              <td><a href="#/orders" class="btn btn-primary btn-sm">View</a></td>
            </tr>`).join('')}
        </tbody>
      </table>`;
}

// ── Row 4: Low Stock ───────────────────────────────────────────────────────────
function renderLowStockTable(inventory) {
  const lowStock = inventory
    .filter(p => p.stock_status === 'low' || p.stock_status === 'out_of_stock')
    .sort((a, b) => a.stock - b.stock)
    .slice(0, 8);

  document.getElementById('dash-low-stock').innerHTML = lowStock.length === 0
    ? `<p class="table-empty" style="color:var(--success)">✓ All products have sufficient stock.</p>`
    : `<table>
        <thead><tr><th>Product</th><th>Category</th><th>Stock</th><th>Threshold</th><th></th></tr></thead>
        <tbody>
          ${lowStock.map(p => `
            <tr>
              <td class="fw-600">${p.product_name}</td>
              <td class="text-muted">${p.category_name || '—'}</td>
              <td class="${stockClass(p.stock)} fw-600 mono">${p.stock}</td>
              <td class="mono text-muted">${p.stock_threshold}</td>
              <td><a href="#/inventory" class="btn btn-ghost btn-sm">Log Restock</a></td>
            </tr>`).join('')}
        </tbody>
      </table>`;
}

// ── Row 5: Recent Activity Feed ────────────────────────────────────────────────
function renderActivityFeed(orders, logs) {
  const activities = [];

  orders.slice(0, 10).forEach(o => {
    activities.push({
      time: o.created_at,
      icon: '🛒',
      text: `New order <strong>${o.reference_number}</strong> from ${o.customer_name} — ${peso(o.total_amount)}`,
      link: '#/orders',
    });
  });

  logs.slice(0, 10).forEach(l => {
    const typeText = {
      walk_in_sale: `Walk-in sale — ${l.quantity} units of ${l.product_name}`,
      restock:      `Restocked ${l.quantity} units of ${l.product_name}`,
      online_order: `Stock deducted for ${l.product_name} (online order)`,
      adjustment:   `Stock adjusted for ${l.product_name}`,
      cancelled_order: `Stock restored for ${l.product_name} (order cancelled)`,
      return:       `Return recorded for ${l.product_name}`,
    };
    activities.push({
      time: l.created_at,
      icon: l.transaction_type === 'walk_in_sale' ? '🏪' : l.transaction_type === 'restock' ? '📦' : '📊',
      text: typeText[l.transaction_type] || `Stock log — ${l.product_name}`,
      link: '#/inventory',
    });
  });

  activities.sort((a, b) => new Date(b.time) - new Date(a.time));
  const recent = activities.slice(0, 12);

  document.getElementById('dash-activity').innerHTML = recent.length === 0
    ? `<p class="table-empty">No recent activity.</p>`
    : `<div style="padding:8px 0">
        ${recent.map(a => `
          <a href="${a.link}" style="display:flex;align-items:center;gap:10px;padding:10px 16px;
             text-decoration:none;color:var(--text);border-bottom:1px solid var(--border)">
            <span style="font-size:16px">${a.icon}</span>
            <span style="flex:1;font-size:13px">${a.text}</span>
            <span style="font-size:11px;color:var(--muted)">${fmtDateTime(a.time)}</span>
          </a>`).join('')}
      </div>`;
}

// ── Real-time listener ─────────────────────────────────────────────────────────
async function _startDashListener() {
  if (_dashListener) { _dashListener(); _dashListener = null; }

  try {
    const { collection, query, orderBy, onSnapshot } = await import(
      'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js'
    );
    const db = window.__db;
    if (!db) return;

    const q = query(collection(db, 'admin_notifications'), orderBy('created_at', 'desc'));

    _dashListener = onSnapshot(q, async () => {
      // Silently reload dashboard data on any new notification
      try { await loadDashboard(); } catch (_) {}
    });
  } catch (_) {}
}