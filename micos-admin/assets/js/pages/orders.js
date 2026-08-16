/**
 * pages/orders.js — Complete rewrite
 * Full order management with items, delivery, GCash, status stepper
 */
let _ordersListener = null;
let _orders = [], _orderPage = 1;

// ── Status config ─────────────────────────────────────────────────────────────
const ORDER_STATUS_FLOW = ['pending', 'processing', 'shipped', 'delivered'];

function statusLabel(status, deliveryType) {
  const labels = {
    pending:   'Pending',
    processing:'Processing',
    shipped:   deliveryType === 'pickup' ? 'Ready for Pickup' : 'Out for Delivery',
    delivered: deliveryType === 'pickup' ? 'Picked Up' : 'Delivered',
    cancelled: 'Cancelled',
  };
  return labels[status] || status;
}

function statusColor(status) {
  const colors = {
    pending:   '#eab308',
    processing:'#3b82f6',
    shipped:   '#a78bfa',
    delivered: '#22c55e',
    cancelled: '#ef4444',
  };
  return colors[status] || '#64748b';
}

function nextStatus(current) {
  const idx = ORDER_STATUS_FLOW.indexOf(current);
  return idx >= 0 && idx < ORDER_STATUS_FLOW.length - 1
    ? ORDER_STATUS_FLOW[idx + 1]
    : null;
}

// ── Page entry ────────────────────────────────────────────────────────────────
async function pageOrders(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left"><h2>Orders</h2><p>Manage and fulfill customer orders</p></div>
    </div>
    <div class="page-body">
      <div class="table-card">
        <div class="table-toolbar">
          <span class="table-title">All Orders</span>
          <input type="search" class="search-input" id="order-search" placeholder="Search ref / customer…" />
          <select id="order-status-filter" style="width:160px">
            <option value="">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="processing">Processing</option>
            <option value="shipped">Out for Delivery</option>
            <option value="delivered">Delivered</option>
            <option value="cancelled">Cancelled</option>
          </select>
          <select id="order-delivery-filter" style="width:140px">
            <option value="">All Types</option>
            <option value="delivery">Delivery</option>
            <option value="pickup">Pickup</option>
          </select>
          <select id="order-pay-filter" style="width:160px">
            <option value="">All Payments</option>
            <option value="unpaid">Unpaid</option>
            <option value="paid">Paid</option>
            <option value="refunded">Refunded</option>
          </select>
        </div>
        <div class="table-wrap"><div id="orders-table">${spinner()}</div></div>
        <div id="orders-pagination"></div>
      </div>
    </div>`;

  document.getElementById('order-search').addEventListener('input', renderOrders);
  document.getElementById('order-status-filter').addEventListener('change', renderOrders);
  document.getElementById('order-delivery-filter').addEventListener('change', renderOrders);
  document.getElementById('order-pay-filter').addEventListener('change', renderOrders);

  await loadOrders();
}

async function loadOrders() {
  document.getElementById('orders-table').innerHTML = spinner();
  try {
    _orders = await API.getAdminOrders();
    renderOrders();
  } catch (err) {
    document.getElementById('orders-table').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

// Start real-time listener for new orders via Firestore
_startOrdersListener();

async function _startOrdersListener() {
  // Clean up any existing listener
  if (_ordersListener) { _ordersListener(); _ordersListener = null; }

  try {
    const { collection, query, orderBy, onSnapshot } = await import(
      'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js'
    );
    const db = window.__db;
    if (!db) return;

   const q = query(
    collection(db, 'admin_notifications'),
    orderBy('created_at', 'desc')
  );

    _ordersListener = onSnapshot(q, async (snap) => {
  if (snap.empty) return;
  const hasNewOrder = snap.docs.some(d => {
    const data = d.data();
    return data.type === 'new_order' && data.read === false;
  });
  if (!hasNewOrder) return;

      // Re-fetch orders silently without destroying the current view
      try {
        const fresh = await API.getAdminOrders();

        // Only update if we have new orders
        if (fresh.length !== _orders.length ||
            fresh[0]?.id !== _orders[0]?.id) {
          _orders = fresh;

          // If modal is open don't touch the table — just update data
          const modalOpen = !document.getElementById('modal-overlay').classList.contains('hidden');
          if (!modalOpen) {
            renderOrders();

            // Highlight the newest row briefly
            const firstRow = document.querySelector('#orders-table tbody tr');
            if (firstRow) {
              firstRow.style.transition = 'background .3s';
              firstRow.style.background = 'rgba(249,115,22,.15)';
              setTimeout(() => { firstRow.style.background = ''; }, 2000);
            }
          }
        }
      } catch (_) {}
    });
  } catch (_) {}
}

// ── List render ───────────────────────────────────────────────────────────────
function renderOrders() {
  const search   = document.getElementById('order-search')?.value.toLowerCase() || '';
  const status   = document.getElementById('order-status-filter')?.value || '';
  const delivery = document.getElementById('order-delivery-filter')?.value || '';
  const pay      = document.getElementById('order-pay-filter')?.value || '';

  const filtered = _orders.filter(o =>
    (!search   || o.reference_number?.toLowerCase().includes(search) ||
                  o.customer_name?.toLowerCase().includes(search)) &&
    (!status   || o.status === status) &&
    (!delivery || o.delivery_type === delivery) &&
    (!pay      || o.payment_status === pay)
  );

  const { items, pages } = paginate(filtered, _orderPage);

  if (items.length === 0) {
    document.getElementById('orders-table').innerHTML = `<p class="table-empty">No orders found.</p>`;
    document.getElementById('orders-pagination').innerHTML = '';
    return;
  }

  document.getElementById('orders-table').innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Reference</th>
          <th>Customer</th>
          <th>Type</th>
          <th>Amount</th>
          <th>Payment</th>
          <th>Status</th>
          <th>Date</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        ${items.map(o => {
          const sc    = statusColor(o.status);
          const lbl   = statusLabel(o.status, o.delivery_type);
    
          return `
          <tr style="border-left:3px solid ${o.status === 'cancelled' ? 'transparent' : sc};opacity:${o.status === 'cancelled' ? '.6' : '1'}">
            <td class="mono text-accent" style="font-size:11px">${o.reference_number}</td>
            <td>
              <div class="fw-600">${o.customer_name}</div>
              <div class="text-muted" style="font-size:11px">${o.customer_phone || o.customer_email}</div>
            </td>
            <td>
              <span class="badge ${o.delivery_type === 'pickup' ? 'badge-default' : 'badge-processing'}">
                ${o.delivery_type === 'pickup' ? '🏪 Pickup' : '🚴 Delivery'}
              </span>
            </td>
            <td class="mono fw-600">${peso(o.total_amount)}</td>
            <td>
              ${badge(o.payment_status)}
            </td>
            <td>
              <span style="display:inline-flex;align-items:center;gap:5px">
                <span style="width:8px;height:8px;border-radius:50%;background:${sc};display:inline-block"></span>
                <span style="font-size:12px;font-weight:600;color:${sc}">${lbl}</span>
              </span>
            </td>
            <td class="text-muted mono" style="font-size:11px">${fmtDateTime(o.created_at)}</td>
            <td>
              <button class="btn btn-ghost btn-sm" onclick="openOrderDetail(${o.id})">View</button>
            </td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>`;

  renderPagination(document.getElementById('orders-pagination'), _orderPage, pages,
    p => { _orderPage = p; renderOrders(); });
}

// ── Order Detail Modal ────────────────────────────────────────────────────────
function openOrderDetail(id) {
  const o = _orders.find(x => x.id === id);
  if (!o) return;

  const items     = o.items || [];
  const delivery  = o.delivery_type;
  const isCancelled = o.status === 'cancelled';
  const next      = nextStatus(o.status);
  const canCancel = ['pending', 'processing'].includes(o.status);
  const subtotal  = items.reduce((s, i) => s + (parseFloat(i.price) * parseInt(i.quantity)), 0);

  // ── Section 1 — Stock check ───────────────────────────────────────────────
  const stockRows = items.map(i => {
    const stock = parseInt(i.current_stock ?? 99);
    const needed = parseInt(i.quantity);
    const ok = stock >= needed;
    return `
      <tr>
        <td class="fw-600">${i.product_name}</td>
        <td class="mono">${needed}</td>
        <td class="mono ${ok ? 'text-success' : 'stock-low'} fw-600">${stock}</td>
        <td>${ok
          ? '<span class="badge badge-in">OK</span>'
          : '<span class="badge badge-cancelled">Low Stock</span>'}</td>
      </tr>`;
  }).join('');

  const hasStockIssue = items.some(i => parseInt(i.current_stock ?? 99) < parseInt(i.quantity));

  // ── Section 2 — Items ordered ─────────────────────────────────────────────
  const itemRows = items.map(i => {
    const sub = parseFloat(i.price) * parseInt(i.quantity);
    return `
      <tr>
        <td>
          <div class="fw-600">${i.product_name}</div>
          ${i.customizations ? `<div class="text-muted" style="font-size:11px">⚙ ${i.customizations}</div>` : ''}
        </td>
        <td class="mono text-muted">${peso(i.price)}</td>
        <td class="mono">×${i.quantity}</td>
        <td class="mono fw-600">${peso(sub)}</td>
      </tr>`;
  }).join('');

  // ── Section 5 — Payment ───────────────────────────────────────────────────
  let paymentSection = '';
  if (o.payment_status === 'unpaid') {
  paymentSection = `<button class="btn btn-primary" onclick="confirmPaymentAction(${o.id})">Mark as Paid</button>`;
   } else {
  paymentSection = `<div style="color:var(--success);font-weight:700;font-size:14px">✓ Payment Confirmed</div>`;
   }

  // ── Section 6 — Status stepper ────────────────────────────────────────────
  const stepperSteps = ORDER_STATUS_FLOW.map((s, i) => {
    const currentIdx = ORDER_STATUS_FLOW.indexOf(o.status);
    const isDone     = i < currentIdx;
    const isActive   = i === currentIdx;
    const color      = isDone || isActive ? statusColor(s) : 'var(--border)';
    return `
      <div style="display:flex;flex-direction:column;align-items:center;flex:1">
        <div style="width:28px;height:28px;border-radius:50%;background:${color};
             display:flex;align-items:center;justify-content:center;
             font-size:11px;font-weight:800;color:#fff;margin-bottom:4px">
          ${isDone ? '✓' : i + 1}
        </div>
        <div style="font-size:10px;text-align:center;color:${isActive ? color : 'var(--muted)'};font-weight:${isActive ? '700' : '400'}">
          ${statusLabel(s, delivery)}
        </div>
      </div>
      ${i < ORDER_STATUS_FLOW.length - 1
        ? `<div style="flex:1;height:2px;background:${isDone ? statusColor(ORDER_STATUS_FLOW[i]) : 'var(--border)'};margin-top:14px;max-width:40px"></div>`
        : ''}`;
  }).join('');

  // ── Section 3 — Delivery address ──────────────────────────────────────────
  let addressSection = '';
  if (delivery === 'pickup') {
    addressSection = `
      <div style="background:var(--surface2);border-radius:8px;padding:14px;font-size:13px;color:var(--muted)">
        🏪 Customer will collect from store in Balanga City.
      </div>`;
  } else {
    const outsideBataan = o.address_province && o.address_province.toLowerCase() !== 'bataan';
    addressSection = `
      ${outsideBataan ? `<div class="alert alert-error" style="margin-bottom:10px">⚠ Delivery address is outside Bataan. Contact customer to verify.</div>` : ''}
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;font-size:13px">
        <div><span class="text-muted">Street / House No.</span><br><strong>${o.address_street || '—'}</strong></div>
        <div><span class="text-muted">Barangay</span><br><strong>${o.address_barangay || '—'}</strong></div>
        <div><span class="text-muted">City / Municipality</span><br><strong>${o.address_city || '—'}</strong></div>
        <div><span class="text-muted">Province</span><br><strong>${o.address_province || '—'}</strong></div>
        <div><span class="text-muted">Zip Code</span><br><strong>${o.address_zipcode || '—'}</strong></div>
        <div><span class="text-muted">Landmark</span><br><strong>${o.address_landmark || '—'}</strong></div>
      </div>
      ${o.delivery_fee > 0 ? `<div style="margin-top:10px;font-size:12px;color:var(--muted)">Delivery fee: <strong class="text-accent">${peso(o.delivery_fee)}</strong></div>` : ''}
      ${o.latitude && o.longitude ? `
        <a href="https://maps.google.com/?q=${o.latitude},${o.longitude}" target="_blank"
           class="btn btn-ghost btn-sm" style="margin-top:10px;display:inline-flex;align-items:center;gap:6px">
          🗺 View on Google Maps
        </a>` : ''}`;
  }

  Modal.open({
    title: `Order — ${o.reference_number}`,
    large: true,
    body: `
      <!-- Section 1: Stock Check -->
      ${hasStockIssue ? `<div class="alert alert-error" style="margin-bottom:16px">⚠ Some items have low stock. Verify before processing.</div>` : ''}
      <div style="margin-bottom:20px">
        <p class="form-section-label">STOCK CHECK</p>
        <table>
          <thead><tr><th>Product</th><th>Ordered</th><th>In Stock</th><th>Status</th></tr></thead>
          <tbody>${stockRows}</tbody>
        </table>
      </div>

      <!-- Section 2: Items Ordered -->
      <div style="margin-bottom:20px">
        <p class="form-section-label">ITEMS ORDERED</p>
        <table>
          <thead><tr><th>Product</th><th>Unit Price</th><th>Qty</th><th>Subtotal</th></tr></thead>
          <tbody>${itemRows}</tbody>
          <tfoot>
            <tr style="border-top:2px solid var(--border)">
              <td colspan="3" class="fw-600 text-muted">Product Subtotal</td>
              <td class="mono fw-600">${peso(subtotal)}</td>
            </tr>
            ${o.delivery_fee > 0 ? `
            <tr>
              <td colspan="3" class="text-muted">Delivery Fee</td>
              <td class="mono">${peso(o.delivery_fee)}</td>
            </tr>` : ''}
            <tr>
              <td colspan="3" class="fw-600" style="font-size:15px">Total Amount</td>
              <td class="mono fw-600 text-accent" style="font-size:15px">${peso(o.total_amount)}</td>
            </tr>
          </tfoot>
        </table>
      </div>

      <!-- Section 3: Delivery Info -->
      <div style="margin-bottom:20px">
        <p class="form-section-label">${delivery === 'pickup' ? 'PICKUP INFO' : 'DELIVERY ADDRESS'}</p>
        ${addressSection}
      </div>

      <!-- Section 4: Customer Info -->
      <div style="margin-bottom:20px">
        <p class="form-section-label">CUSTOMER</p>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;font-size:13px">
          <div><span class="text-muted">Name</span><br><strong>${o.customer_name}</strong></div>
          <div><span class="text-muted">Email</span><br><strong>${o.customer_email}</strong></div>
          <div><span class="text-muted">Phone</span><br><strong>${o.customer_phone || '—'}</strong></div>
        </div>
      </div>

      <!-- Section 5: Payment -->
      <div style="margin-bottom:20px">
        <p class="form-section-label">PAYMENT</p>
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px">
          <span class="text-muted" style="font-size:13px">Method:</span>
          <strong style="font-size:13px">${(o.payment_method || '—').toUpperCase().replace('_',' ')}</strong>
          <span style="margin-left:8px">${badge(o.payment_status)}</span>
        </div>
        ${paymentSection}
      </div>

      <!-- Section 6: Status Stepper -->
      ${!isCancelled ? `
      <div style="margin-bottom:20px">
        <p class="form-section-label">ORDER STATUS</p>
        <div style="display:flex;align-items:center;justify-content:space-between;padding:16px 8px">
          ${stepperSteps}
        </div>
        <div id="status-action-area" style="margin-top:16px"></div>
      </div>` : ''}

      <!-- Section 7: Cancellation Info -->
      ${isCancelled ? `
      <div style="margin-bottom:20px">
        <p class="form-section-label">CANCELLATION</p>
        <div style="background:rgba(239,68,68,.08);border:1px solid rgba(239,68,68,.3);border-radius:8px;padding:14px">
          <div style="font-size:12px;color:var(--muted);margin-bottom:4px">
            Cancelled by: <strong>${o.cancelled_by === 'admin' ? 'Admin' : 'Customer'}</strong>
          </div>
          <div style="font-size:13px;color:var(--text)">${o.cancellation_reason || 'No reason provided.'}</div>
        </div>
      </div>` : ''}

      <div id="order-action-err"></div>`,

    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Close</button>
      ${canCancel ? `<button class="btn btn-danger" id="cancel-order-btn">Cancel Order</button>` : ''}
      ${next && !isCancelled ? `<button class="btn btn-primary" id="advance-order-btn">
        Mark as ${statusLabel(next, delivery)} →
      </button>` : ''}`,
  });

  // ── Status advance ────────────────────────────────────────────────────────
  document.getElementById('advance-order-btn')?.addEventListener('click', () => {
    const nextSt = nextStatus(o.status);
    if (!nextSt) return;

    confirmDelete(
      `Move order <strong>${o.reference_number}</strong> to <strong>${statusLabel(nextSt, delivery)}</strong>?`,
      async () => {
        try {
          await API.updateOrderStatus(o.id, { status: nextSt });
          toast(`Order moved to ${statusLabel(nextSt, delivery)}!`, 'success');
          Modal.close();
          await loadOrders();
        } catch (err) {
          document.getElementById('order-action-err').innerHTML = `<div class="alert alert-error">${err.message}</div>`;
        }
      },
      { title: 'Confirm Status Update', buttonText: 'Confirm' }
    );
  });

  // ── Cancel order ──────────────────────────────────────────────────────────
  document.getElementById('cancel-order-btn')?.addEventListener('click', () => {
    Modal.open({
      title: 'Cancel Order',
      body: `
        <p style="color:var(--muted);margin-bottom:14px">
          You are cancelling order <strong>${o.reference_number}</strong> for <strong>${o.customer_name}</strong>.
          Stock will be automatically restored.
        </p>
        <div class="form-group">
          <label>Cancellation Reason (required)</label>
          <textarea id="cancel-reason" rows="3" placeholder="e.g. Out of stock, Customer requested…"></textarea>
        </div>
        <div id="cancel-err"></div>`,
      footer: `
        <button class="btn btn-secondary" onclick="openOrderDetail(${o.id})">Go Back</button>
        <button class="btn btn-danger" id="confirm-cancel-btn">Confirm Cancellation</button>`,
    });

    document.getElementById('confirm-cancel-btn').addEventListener('click', async () => {
      const reason = document.getElementById('cancel-reason').value.trim();
      if (!reason) {
        document.getElementById('cancel-err').innerHTML = `<div class="alert alert-error">Please provide a cancellation reason.</div>`;
        return;
      }
      try {
        await API.updateOrderStatus(o.id, { status: 'cancelled', cancellation_reason: reason });
        toast('Order cancelled. Stock has been restored.', 'success');
        Modal.close();
        await loadOrders();
      } catch (err) {
        document.getElementById('cancel-err').innerHTML = `<div class="alert alert-error">${err.message}</div>`;
      }
    });
  });
}

// ── Confirm Payment ───────────────────────────────────────────────────────────
async function confirmPaymentAction(orderId) {
  const o = _orders.find(x => x.id === orderId);
  if (!o) return;

  confirmDelete(
    `Confirm payment of <strong>${peso(o.total_amount)}</strong> for order <strong>${o.reference_number}</strong>?
     This will mark the order as paid and notify the customer.`,
    async () => {
      try {
        await API.confirmPayment(orderId);
        toast('Payment confirmed! Customer has been notified.', 'success');
        Modal.close();
        await loadOrders();
      } catch (err) { toast(err.message, 'error'); }
    },
    { title: 'Confirm Payment', buttonText: 'Confirm Payment' }
  );
}
