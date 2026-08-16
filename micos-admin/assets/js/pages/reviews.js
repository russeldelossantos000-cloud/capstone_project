/**
 * pages/reviews.js
 * Admin view of all product reviews — moderation and deletion.
 */
let _reviews = [], _reviewPage = 1;

async function pageReviews(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left">
        <h2>Reviews</h2>
        <p>Moderate customer product reviews</p>
      </div>
    </div>
    <div class="page-body">
      <div class="table-card">
        <div class="table-toolbar">
          <span class="table-title">All Reviews</span>
          <input type="search" class="search-input" id="review-search"
            placeholder="Search product / reviewer…" />
          <select id="review-rating-filter" style="width:130px">
            <option value="">All Ratings</option>
            <option value="5">★★★★★ 5</option>
            <option value="4">★★★★☆ 4</option>
            <option value="3">★★★☆☆ 3</option>
            <option value="2">★★☆☆☆ 2</option>
            <option value="1">★☆☆☆☆ 1</option>
          </select>
        </div>
        <div class="table-wrap"><div id="reviews-table">${spinner()}</div></div>
        <div id="reviews-pagination"></div>
      </div>
    </div>`;

  document.getElementById('review-search').addEventListener('input', renderReviews);
  document.getElementById('review-rating-filter').addEventListener('change', renderReviews);

  try {
    _reviews = await API.getAdminReviews();
    renderReviews();
  } catch (err) {
    document.getElementById('reviews-table').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderReviews() {
  const search = document.getElementById('review-search')?.value.toLowerCase()  || '';
  const rating = document.getElementById('review-rating-filter')?.value          || '';

  const filtered = _reviews.filter(r =>
    (!search || r.product_name?.toLowerCase().includes(search) ||
                r.reviewer_name?.toLowerCase().includes(search)) &&
    (!rating || String(r.rating) === rating)
  );

  const { items, pages } = paginate(filtered, _reviewPage);

  if (items.length === 0) {
    document.getElementById('reviews-table').innerHTML = `<p class="table-empty">No reviews found.</p>`;
    document.getElementById('reviews-pagination').innerHTML = '';
    return;
  }

  document.getElementById('reviews-table').innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Product</th>
          <th>Reviewer</th>
          <th>Rating</th>
          <th>Comment</th>
          <th>Date</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        ${items.map(r => `
          <tr>
            <td class="fw-600">${r.product_name || '—'}</td>
            <td class="text-muted">${r.reviewer_name || '—'}</td>
            <td>${renderStars(r.rating)}</td>
            <td class="text-muted" style="max-width:260px;font-size:12px">
              ${r.comment
                ? `<span title="${r.comment.replace(/"/g,'&quot;')}">${r.comment.length > 80 ? r.comment.slice(0, 80) + '…' : r.comment}</span>`
                : '<em>No comment</em>'}
            </td>
            <td class="text-muted mono" style="font-size:11px">${fmtDate(r.created_at)}</td>
            <td>
              <button class="btn btn-danger btn-sm"
                onclick="deleteReview(${r.id}, '${(r.reviewer_name || '').replace(/'/g,"\\'")}')">
                Delete
              </button>
            </td>
          </tr>`).join('')}
      </tbody>
    </table>`;

  renderPagination(
    document.getElementById('reviews-pagination'),
    _reviewPage, pages,
    p => { _reviewPage = p; renderReviews(); }
  );
}

function renderStars(rating) {
  const n = parseInt(rating) || 0;
  return `<span style="color:#f59e0b;font-size:13px;letter-spacing:1px">${'★'.repeat(n)}${'☆'.repeat(5 - n)}</span>
          <span class="mono text-muted" style="font-size:11px;margin-left:4px">${n}/5</span>`;
}

async function deleteReview(id, name) {
  confirmDelete(
    `Delete review by <strong>${name}</strong>? This cannot be undone.`,
    async () => {
      try {
        await API.deleteReview(id);
        toast('Review deleted.', 'success');
        _reviews = await API.getAdminReviews();
        renderReviews();
      } catch (err) {
        toast(err.message, 'error');
      }
    }
  );
}
