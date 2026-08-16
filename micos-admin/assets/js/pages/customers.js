/**
 * pages/customers.js
 * Two tabs: Users / Reviews
 */

let _customers = [], _reviews = [];
let _custPage = 1, _revPage = 1;

async function pageCustomers(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left">
        <h2>Customers</h2>
        <p>Manage customer accounts and moderate reviews</p>
      </div>
    </div>
    <div class="page-body">
      <div class="tabs-bar">
        <button class="tab-btn active" data-tab="users">Users</button>
        <button class="tab-btn" data-tab="reviews">Reviews</button>
      </div>
      <div id="cust-tab-content">${spinner()}</div>
    </div>`;

  document.querySelectorAll('.tab-btn').forEach(btn =>
    btn.addEventListener('click', () => switchCustTab(btn.dataset.tab)));

  await switchCustTab('users');
}

async function switchCustTab(tab) {
  document.querySelectorAll('.tab-btn').forEach(b =>
    b.classList.toggle('active', b.dataset.tab === tab));
  const content = document.getElementById('cust-tab-content');
  content.innerHTML = spinner();
  if (tab === 'users')   await renderUsersTab(content);
  if (tab === 'reviews') await renderReviewsTab(content);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — USERS
// ══════════════════════════════════════════════════════════════════════════════

async function renderUsersTab(content) {
  content.innerHTML = `
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">All Customers</span>
        <input type="search" class="search-input" id="cust-search" placeholder="Search name / email / phone…" />
        <select id="cust-order-filter" style="width:160px">
          <option value="">All Customers</option>
          <option value="has_orders">Has Orders</option>
          <option value="no_orders">No Orders Yet</option>
        </select>
      </div>
      <div class="table-wrap"><div id="cust-table">${spinner()}</div></div>
      <div id="cust-pagination"></div>
    </div>`;

  document.getElementById('cust-search').addEventListener('input', renderCustomersTable);
  document.getElementById('cust-order-filter').addEventListener('change', renderCustomersTable);

  try {
    const [users, orders] = await Promise.all([
      API.getUsers(),
      API.getAdminOrders(),
    ]);

    // Enrich users with order stats
    _customers = users.map(u => {
      const userOrders = orders.filter(o => o.user_id === u.id);
      const paidOrders = userOrders.filter(o => o.payment_status === 'paid');
      return {
        ...u,
        order_count:   userOrders.length,
        total_spent:   paidOrders.reduce((s, o) => s + parseFloat(o.total_amount || 0), 0),
        last_order:    userOrders[0]?.created_at || null,
        fav_payment:   _mostCommon(userOrders.map(o => o.payment_method)),
        fav_delivery:  _mostCommon(userOrders.map(o => o.delivery_type)),
      };
    });

    renderCustomersTable();
  } catch (err) {
    document.getElementById('cust-table').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function _mostCommon(arr) {
  if (!arr.length) return null;
  return arr.sort((a, b) =>
    arr.filter(v => v === a).length - arr.filter(v => v === b).length
  ).pop();
}

function renderCustomersTable() {
  const search = document.getElementById('cust-search')?.value.toLowerCase() || '';
  const filter = document.getElementById('cust-order-filter')?.value || '';

  const filtered = _customers.filter(u =>
    (!search || u.first_name?.toLowerCase().includes(search) ||
                u.last_name?.toLowerCase().includes(search) ||
                u.email?.toLowerCase().includes(search) ||
                u.phone?.toLowerCase().includes(search)) &&
    (!filter ||
      (filter === 'has_orders'  && u.order_count > 0) ||
      (filter === 'no_orders'   && u.order_count === 0))
  );

  const { items, pages } = paginate(filtered, _custPage);

  document.getElementById('cust-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No customers found.</p>`
    : `<table>
        <thead>
          <tr>
            <th>Name</th><th>Email</th><th>Phone</th><th>City</th>
            <th>Orders</th><th>Total Spent</th><th>Joined</th><th></th>
          </tr>
        </thead>
        <tbody>
          ${items.map(u => `
            <tr>
              <td class="fw-600">${u.first_name} ${u.last_name || ''}</td>
              <td class="text-muted" style="font-size:12px">${u.email}</td>
              <td class="mono text-muted">${u.phone || '—'}</td>
              <td class="text-muted">${u.address_city || '—'}</td>
              <td>
                <span class="badge ${u.order_count > 0 ? 'badge-processing' : 'badge-default'}">
                  ${u.order_count} order${u.order_count !== 1 ? 's' : ''}
                </span>
              </td>
              <td class="mono">${u.total_spent > 0 ? peso(u.total_spent) : '—'}</td>
              <td class="text-muted mono" style="font-size:11px">${fmtDate(u.created_at)}</td>
              <td>
                <button class="btn btn-ghost btn-sm" onclick="openCustomerProfile(${u.id})">View</button>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('cust-pagination'), _custPage, pages,
    p => { _custPage = p; renderCustomersTable(); });
}

function openCustomerProfile(userId) {
  const u = _customers.find(x => x.id === userId);
  if (!u) return;

  const allOrders = _orders || [];
  const userOrders = allOrders.filter(o => o.user_id === userId);

  Modal.open({
    title: `${u.first_name} ${u.last_name || ''}`,
    large: true,
    body: `
      <!-- Personal Info -->
      <p class="form-section-label">PERSONAL INFO</p>
      <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;font-size:13px;margin-bottom:20px">
        <div><span class="text-muted">Email</span><br><strong>${u.email}</strong></div>
        <div><span class="text-muted">Phone</span><br><strong>${u.phone || '—'}</strong></div>
        <div><span class="text-muted">Member Since</span><br><strong>${fmtDate(u.created_at)}</strong></div>
        <div><span class="text-muted">Street</span><br><strong>${u.address_street || '—'}</strong></div>
        <div><span class="text-muted">Barangay</span><br><strong>${u.address_barangay || '—'}</strong></div>
        <div><span class="text-muted">City</span><br><strong>${u.address_city || '—'}</strong></div>
        <div><span class="text-muted">Province</span><br><strong>${u.address_province || '—'}</strong></div>
        <div><span class="text-muted">Zip</span><br><strong>${u.address_zipcode || '—'}</strong></div>
        <div><span class="text-muted">Landmark</span><br><strong>${u.address_landmark || '—'}</strong></div>
      </div>
      ${u.latitude && u.longitude ? `
        <a href="https://maps.google.com/?q=${u.latitude},${u.longitude}" target="_blank"
           class="btn btn-ghost btn-sm" style="margin-bottom:16px">
          🗺 View Saved Location on Maps
        </a>` : ''}

      <!-- Order Summary -->
      <p class="form-section-label">ORDER SUMMARY</p>
      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:20px">
        <div class="stat-card">
          <div class="stat-label">Total Orders</div>
          <div class="stat-value">${u.order_count}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Total Spent</div>
          <div class="stat-value accent">${u.total_spent > 0 ? peso(u.total_spent) : '—'}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Fav Payment</div>
          <div class="stat-value" style="font-size:14px">${u.fav_payment || '—'}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Fav Delivery</div>
          <div class="stat-value" style="font-size:14px">${u.fav_delivery || '—'}</div>
        </div>
      </div>

      <!-- Order History -->
      <p class="form-section-label">ORDER HISTORY</p>
      ${userOrders.length === 0
        ? `<p class="table-empty">No orders yet.</p>`
        : `<table>
            <thead><tr><th>Reference</th><th>Amount</th><th>Status</th><th>Payment</th><th>Date</th></tr></thead>
            <tbody>
              ${userOrders.slice(0, 10).map(o => `
                <tr>
                  <td class="mono text-accent" style="font-size:11px">${o.reference_number}</td>
                  <td class="mono">${peso(o.total_amount)}</td>
                  <td>${badge(o.status)}</td>
                  <td>${badge(o.payment_status)}</td>
                  <td class="text-muted mono" style="font-size:11px">${fmtDateTime(o.created_at)}</td>
                </tr>`).join('')}
            </tbody>
          </table>`}`,
    footer: `<button class="btn btn-secondary" onclick="Modal.close()">Close</button>`,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — REVIEWS
// ══════════════════════════════════════════════════════════════════════════════

async function renderReviewsTab(content) {
  content.innerHTML = `
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">Product Reviews</span>
        <input type="search" class="search-input" id="rev-search"
          placeholder="Search product / reviewer…" />
        <select id="rev-rating-filter" style="width:130px">
          <option value="">All Ratings</option>
          <option value="5">★★★★★ 5</option>
          <option value="4">★★★★☆ 4</option>
          <option value="3">★★★☆☆ 3</option>
          <option value="2">★★☆☆☆ 2</option>
          <option value="1">★☆☆☆☆ 1</option>
        </select>
      </div>
      <div class="table-wrap"><div id="rev-table">${spinner()}</div></div>
      <div id="rev-pagination"></div>
    </div>`;

  document.getElementById('rev-search').addEventListener('input', renderReviewsTable);
  document.getElementById('rev-rating-filter').addEventListener('change', renderReviewsTable);
  

  try {
    _reviews = await API.getAdminReviews();
    renderReviewsTable();
  } catch (err) {
    document.getElementById('rev-table').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderReviewsTable() {
  const search   = document.getElementById('rev-search')?.value.toLowerCase() || '';
  const rating   = document.getElementById('rev-rating-filter')?.value || '';
  

  const filtered = _reviews.filter(r =>
    (!search   || r.product_name?.toLowerCase().includes(search) ||
                  r.reviewer_name?.toLowerCase().includes(search)) &&
    (!rating   || String(r.rating) === rating) 
    
  );

  const { items, pages } = paginate(filtered, _revPage);

  document.getElementById('rev-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No reviews found.</p>`
    : `<table>
        <thead>
          <tr>
            <th>Product</th><th>Reviewer</th><th>Rating</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(r => `
            <tr>
              <td class="fw-600">${r.product_name || '—'}</td>
              <td class="text-muted">${r.reviewer_name || '—'}</td>
              <td>
                <span style="color:#f59e0b">${'★'.repeat(r.rating)}${'☆'.repeat(5-r.rating)}</span>
                <span class="mono text-muted" style="font-size:11px"> ${r.rating}/5</span>
              </td>
              <td class="text-muted" style="max-width:220px;font-size:12px">
                ${r.comment
                  ? `<span title="${r.comment.replace(/"/g,'&quot;')}">${r.comment.length > 70 ? r.comment.slice(0,70)+'…' : r.comment}</span>`
                  : '<em>No comment</em>'}
              </td>
              
              <td class="text-muted mono" style="font-size:11px">${fmtDate(r.created_at)}</td>
              <td>
                <button class="btn btn-danger btn-sm"
                  onclick="deleteCustomerReview(${r.id}, '${(r.reviewer_name||'').replace(/'/g,"\\'")}')">
                  Delete
                </button>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('rev-pagination'), _revPage, pages,
    p => { _revPage = p; renderReviewsTable(); });
}

async function deleteCustomerReview(id, name) {
  confirmDelete(
    `Delete review by <strong>${name}</strong>? This cannot be undone.`,
    async () => {
      try {
        await API.deleteReview(id);
        toast('Review deleted.', 'success');
        _reviews = await API.getAdminReviews();
        renderReviewsTable();
      } catch (err) { toast(err.message, 'error'); }
    }
  );
}