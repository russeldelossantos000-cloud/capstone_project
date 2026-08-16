/**
 * pages/products.js
 */
let _products = [], _categories = [], _brands = [], _productPage = 1;



async function pageProducts(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left"><h2>Products</h2><p></p></div>
      <button class="btn btn-primary" id="add-product-btn">+ Add Product</button>
    </div>
    <div class="page-body">
      <div class="table-card">
        <div class="table-toolbar">
          <span class="table-title">All Products</span>
          <input type="search" class="search-input" id="product-search" placeholder="Search products…" />
          <select id="product-cat-filter" style="width:160px">
            <option value="">All Categories</option>
          </select>
          <select id="product-brand-filter" style="width:140px">
            <option value="">All Brands</option>
          </select>
        </div>
        <div class="table-wrap"><div id="products-table">${spinner()}</div></div>
        <div id="products-pagination"></div>
      </div>
    </div>`;

  document.getElementById('add-product-btn').addEventListener('click', () => openProductForm());

  try {
    [_products, _categories, _brands] = await Promise.all([API.getProducts(), API.getCategories(), API.getBrands()]);

    // Populate filters
    const catFilter   = document.getElementById('product-cat-filter');
    const brandFilter = document.getElementById('product-brand-filter');
    _categories.forEach(c => catFilter.insertAdjacentHTML('beforeend', `<option value="${c.id}">${c.category_name}</option>`));
    _brands.forEach(b     => brandFilter.insertAdjacentHTML('beforeend', `<option value="${b.id}">${b.brand_name}</option>`));

    renderProducts();
    document.getElementById('product-search').addEventListener('input',   renderProducts);
    catFilter.addEventListener('change', renderProducts);
    brandFilter.addEventListener('change', renderProducts);
  } catch (err) {
    document.getElementById('products-table').innerHTML = `<div class="alert alert-error" style="margin:16px">Failed: ${err.message}</div>`;
  }
}

function renderProducts() {
  const search   = document.getElementById('product-search')?.value.toLowerCase() || '';
  const catId    = document.getElementById('product-cat-filter')?.value || '';
  const brandId  = document.getElementById('product-brand-filter')?.value || '';

  let filtered = _products.filter(p =>
    (!search  || p.product_name.toLowerCase().includes(search)) &&
    (!catId   || String(p.category_id) === catId) &&
    (!brandId || String(p.brand_id)    === brandId)
  );

  const { items, pages } = paginate(filtered, _productPage);

  if (items.length === 0) {
    document.getElementById('products-table').innerHTML = `<p class="table-empty">No products found.</p>`;
    document.getElementById('products-pagination').innerHTML = '';
    return;
  }

  document.getElementById('products-table').innerHTML = `
    <table>
      <thead><tr><th>ID</th><th>Image</th><th>Product</th><th>Category</th><th>Brand</th><th>Price</th><th>Stock</th><th>Custom</th><th></th></tr></thead>
      <tbody>
        ${items.map(p => `
          <tr>
            <td class="mono text-muted">#${p.id}</td>
            <td>${p.image ? `<img class="thumb" src="${API.imgUrl(p.image)}" alt="" onerror="this.style.display='none'">` : `<div class="thumb"></div>`}</td>
            <td class="fw-600">${p.product_name}</td>
            <td class="text-muted">${p.category_name || '—'}</td>
            <td class="text-muted">${p.brand_name    || '—'}</td>
            <td class="mono">${peso(p.price)}</td>
            <td class="${stockClass(p.stock)} mono fw-600">${p.stock}</td>
            <td>${p.is_customizable ? '<span class="badge badge-in">Yes</span>' : '<span class="badge badge-default">No</span>'}</td>
            <td>
              <div class="actions-cell">
                <button class="btn btn-ghost btn-sm" onclick="openProductForm(${p.id})">Edit</button>
                <button class="btn btn-danger btn-sm" onclick="deleteProduct(${p.id}, '${p.product_name.replace(/'/g,"\\'")}')">Del</button>
              </div>
            </td>
          </tr>`).join('')}
      </tbody>
    </table>`;

  renderPagination(document.getElementById('products-pagination'), _productPage, pages, (p) => {
    _productPage = p; renderProducts();
  });
}

function openProductForm(id = null) {
  const p = id ? _products.find(x => x.id === id) : null;

  const catOptions   = _categories.map(c => `<option value="${c.id}" ${p?.category_id == c.id ? 'selected' : ''}>${c.category_name}</option>`).join('');
  const brandOptions = _brands.map(b    => `<option value="${b.id}" ${p?.brand_id    == b.id ? 'selected' : ''}>${b.brand_name}</option>`).join('');

  Modal.open({
    title: id ? 'Edit Product' : 'Add Product',
    large: true,
    body: `
      <div class="form-row">
        <div class="form-group">
          <label>Product Name </label>
          <input type="text" id="f-name" value="${p?.product_name || ''}" />
        </div>
        <div class="form-group">
          <label>Price </label>
          <input type="number" id="f-price" step="0.01" value="${p?.price || ''}" />
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Category </label>
          <select id="f-category"><option value="">Select…</option>${catOptions}</select>
        </div>
        <div class="form-group">
          <label>Brand</label>
          <select id="f-brand"><option value="">None</option>${brandOptions}</select>
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Stock </label>
          <input type="number" id="f-stock" value="${p?.stock || ''}" />
        </div>
        <div class="form-group">
          <label>Is Customizable</label>
          <select id="f-custom">
            <option value="0" ${!p?.is_customizable ? 'selected' : ''}>No</option>
            <option value="1" ${p?.is_customizable  ? 'selected' : ''}>Yes</option>
          </select>
        </div>
      </div>

      <!-- Image upload section -->
      <div class="form-group">
        <label>Product Image</label>
        <div id="upload-zone" style="border:2px dashed var(--border);border-radius:10px;padding:20px;text-align:center;cursor:pointer;transition:border-color .2s;position:relative"
             onclick="document.getElementById('f-image-file').click()"
             ondragover="event.preventDefault();this.style.borderColor='var(--accent)'"
             ondragleave="this.style.borderColor='var(--border)'"
             ondrop="handleImageDrop(event)">
          <input type="file" id="f-image-file" accept="image/jpeg,image/png,image/webp,image/gif"
                 style="display:none" onchange="handleImageSelect(this)" />
          <div id="upload-placeholder">
            <p style="color:var(--muted);font-size:13px;margin:0">
              <strong style="color:var(--text)">Click to upload</strong> or drag & drop<br>
              JPG, PNG, WebP, GIF — max 5 MB
            </p>
          </div>
          <div id="upload-preview" style="display:none">
            <img id="preview-img" style="max-height:140px;max-width:100%;border-radius:8px;object-fit:contain" />
            <p id="preview-name" style="color:var(--muted);font-size:11px;margin:8px 0 0"></p>
          </div>
        </div>
        ${p?.image ? `
          <div style="margin-top:10px;display:flex;align-items:center;gap:10px">
            <img src="${p.image}" style="width:48px;height:48px;border-radius:6px;object-fit:cover;border:1px solid var(--border)"
                 onerror="this.style.display='none'" />
            <div>
              <p style="font-size:12px;color:var(--muted);margin:0">Current image</p>
              <label style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);cursor:pointer;margin-top:4px">
                <input type="checkbox" id="f-keep-image" checked />
                Keep current image if no new file selected
              </label>
            </div>
          </div>` : ''}
        <input type="hidden" id="f-image-url" value="${p?.image || ''}" />
        <div id="upload-progress" style="display:none;margin-top:8px">
          <div style="height:4px;background:var(--border);border-radius:2px">
            <div id="progress-bar" style="height:100%;width:0%;background:var(--accent);border-radius:2px;transition:width .3s"></div>
          </div>
          <p style="font-size:11px;color:var(--muted);margin:4px 0 0">Uploading…</p>
        </div>
      </div>

      <div class="form-group">
        <label>Description</label>
        <textarea id="f-desc">${p?.description || ''}</textarea>
      </div>
      <div id="form-err"></div>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-primary" id="save-product-btn">${id ? 'Update' : 'Create'}</button>`,
  });

  document.getElementById('save-product-btn').addEventListener('click', async () => {
    const btn      = document.getElementById('save-product-btn');
    const errEl    = document.getElementById('form-err');
    const name     = document.getElementById('f-name').value.trim();
    const price    = document.getElementById('f-price').value;
    const catId    = document.getElementById('f-category').value;
    const stock    = document.getElementById('f-stock').value;

    if (!name || !price || !catId || !stock) {
      errEl.innerHTML = `<div class="alert alert-error">Please fill all required fields.</div>`;
      return;
    }

    btn.disabled = true;
    btn.textContent = 'Saving…';

    try {
      // ── Upload image first if a file was selected ──────────────────────────
      let imageUrl = document.getElementById('f-image-url').value;
      const fileInput = document.getElementById('f-image-file');

      if (fileInput?.files?.length > 0) {
        imageUrl = await uploadProductImage(fileInput.files[0]);
      } else if (id && document.getElementById('f-keep-image')?.checked === false) {
        imageUrl = null; // Admin unchecked "keep current"
      }

      // ── Save product ──────────────────────────────────────────────────────
      const body = {
        product_name:    name,
        price,
        category_id:     catId,
        brand_id:        document.getElementById('f-brand').value || null,
        stock,
        is_customizable: document.getElementById('f-custom').value,
        image:           imageUrl || null,
        description:     document.getElementById('f-desc').value.trim() || null,
      };

      if (id) await API.updateProduct(id, body);
      else    await API.createProduct(body);

      toast(id ? 'Product updated!' : 'Product created!', 'success');
      Modal.close();
      _products = await API.getProducts();
      renderProducts();
    } catch (err) {
      errEl.innerHTML = `<div class="alert alert-error">${err.message}</div>`;
    } finally {
      btn.disabled    = false;
      btn.textContent = id ? 'Update' : 'Create';
    }
  });
}

// ── Upload helpers ─────────────────────────────────────────────────────────────

function handleImageSelect(input) {
  const file = input.files[0];
  if (!file) return;
  showImagePreview(file);
}

function handleImageDrop(event) {
  event.preventDefault();
  document.getElementById('upload-zone').style.borderColor = 'var(--border)';
  const file = event.dataTransfer.files[0];
  if (!file || !file.type.startsWith('image/')) {
    toast('Please drop an image file.', 'error'); return;
  }
  document.getElementById('f-image-file').files = event.dataTransfer.files;
  showImagePreview(file);
}

function showImagePreview(file) {
  const reader = new FileReader();
  reader.onload = e => {
    document.getElementById('upload-placeholder').style.display = 'none';
    document.getElementById('upload-preview').style.display     = 'block';
    document.getElementById('preview-img').src  = e.target.result;
    document.getElementById('preview-name').textContent = `${file.name} (${(file.size / 1024).toFixed(0)} KB)`;
  };
  reader.readAsDataURL(file);
}

async function uploadProductImage(file) {
  const progressWrap = document.getElementById('upload-progress');
  const progressBar  = document.getElementById('progress-bar');
  progressWrap.style.display = 'block';

  const formData = new FormData();
  formData.append('image', file);

  const token = localStorage.getItem('admin_token');

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', API.BASE_URL + '/upload/product-image');
    xhr.setRequestHeader('Authorization', `Bearer ${token}`);

    xhr.upload.onprogress = e => {
      if (e.lengthComputable) {
        const pct = Math.round((e.loaded / e.total) * 100);
        progressBar.style.width = pct + '%';
      }
    };

    xhr.onload = () => {
      progressWrap.style.display = 'none';
      try {
        const res = JSON.parse(xhr.responseText);
        if (xhr.status >= 200 && xhr.status < 300) resolve(res.image_url);
        else reject(new Error(res.error || 'Upload failed'));
      } catch { reject(new Error('Upload failed')); }
    };

    xhr.onerror = () => { progressWrap.style.display = 'none'; reject(new Error('Network error during upload')); };
    xhr.send(formData);
  });
}

async function deleteProduct(id, name) {
  confirmDelete(`Delete product <strong>${name}</strong>? This cannot be undone.`, async () => {
    try {
      await API.deleteProduct(id);
      toast('Product deleted.', 'success');
      _products = await API.getProducts();
      renderProducts();
    } catch (err) { toast(err.message, 'error'); }
  });
}

// ── Product image gallery manager ─────────────────────────────────────────────

async function manageProductImages(productId, productName) {
  Modal.open({ title: `Images — ${productName}`, large: true, body: spinner() });
  await refreshImageManager(productId, productName);
}

async function refreshImageManager(productId, productName) {
  try {
    const images = await API.getProductImages(productId);
    document.getElementById('modal-body').innerHTML = `
      <!-- Existing images -->
      <p style="font-size:11px;font-weight:700;color:var(--muted);letter-spacing:1.5px;margin-bottom:10px">
        CURRENT IMAGES (${images.length})
      </p>
      ${images.length === 0
        ? `<p style="color:var(--muted);font-size:13px;margin-bottom:16px">No images yet.</p>`
        : `<div style="display:flex;flex-wrap:wrap;gap:10px;margin-bottom:20px">
            ${images.map(img => `
              <div style="position:relative;display:inline-block">
                <img src="${img.image_url}" style="width:90px;height:90px;object-fit:cover;border-radius:8px;
                     border:2px solid ${img.is_primary ? 'var(--accent)' : 'var(--border)'}"
                     onerror="this.src=''" />
                ${img.is_primary
                  ? `<span style="position:absolute;top:4px;left:4px;background:var(--accent);color:#000;
                       font-size:9px;font-weight:800;padding:2px 5px;border-radius:4px">PRIMARY</span>`
                  : `<button onclick="setProductImagePrimary(${img.id}, ${productId}, '${productName.replace(/'/g, "\\'")}')"
                       style="position:absolute;top:4px;left:4px;background:rgba(0,0,0,.6);color:#fff;
                              border:none;font-size:9px;cursor:pointer;padding:2px 5px;border-radius:4px">
                       Set primary</button>`}
                <button onclick="deleteProductImage(${img.id}, ${productId}, '${productName.replace(/'/g, "\\'")}')"
                    style="position:absolute;top:4px;right:4px;background:var(--danger);color:#fff;
                           border:none;cursor:pointer;width:20px;height:20px;border-radius:50%;
                           font-size:13px;line-height:1;display:flex;align-items:center;justify-content:center">×</button>
              </div>`).join('')}
          </div>`}

      <hr style="border-color:var(--border);margin:0 0 16px" />

      <!-- Upload new images -->
      <p style="font-size:11px;font-weight:700;color:var(--muted);letter-spacing:1.5px;margin-bottom:10px">
        ADD NEW IMAGES
      </p>
      <div id="multi-upload-zone"
           style="border:2px dashed var(--border);border-radius:10px;padding:20px;text-align:center;cursor:pointer"
           onclick="document.getElementById('multi-img-input').click()"
           ondragover="event.preventDefault();this.style.borderColor='var(--accent)'"
           ondragleave="this.style.borderColor='var(--border)'"
           ondrop="handleMultiDrop(event, ${productId}, '${productName.replace(/'/g, "\\'")}')">
        <input type="file" id="multi-img-input" multiple accept="image/*"
               style="display:none"
               onchange="handleMultiSelect(this, ${productId}, '${productName.replace(/'/g, "\\'")}')"/>
        <p style="color:var(--muted);font-size:13px;margin:0">
          <strong style="color:var(--text)">Click or drag</strong> to add images (multiple allowed)
        </p>
      </div>
      <div id="multi-upload-list" style="margin-top:10px;display:flex;flex-direction:column;gap:6px"></div>
      <div id="img-mgr-err" style="margin-top:8px"></div>`;

    document.getElementById('modal-footer').innerHTML = `
      <button class="btn btn-secondary" onclick="Modal.close()">Close</button>
      <button class="btn btn-primary" id="upload-all-btn" style="display:none"
              onclick="uploadAllPendingImages(${productId}, '${productName.replace(/'/g, "\\'")}')">
        Upload Selected
      </button>`;
  } catch (err) {
    document.getElementById('modal-body').innerHTML =
      `<div class="alert alert-error">${err.message}</div>`;
  }
}

// Pending files for multi-upload
let _pendingFiles = [];

function handleMultiSelect(input, productId, productName) {
  _pendingFiles = Array.from(input.files);
  renderPendingList();
  document.getElementById('upload-all-btn').style.display =
    _pendingFiles.length > 0 ? '' : 'none';
}

function handleMultiDrop(event, productId, productName) {
  event.preventDefault();
  document.getElementById('multi-upload-zone').style.borderColor = 'var(--border)';
  _pendingFiles = Array.from(event.dataTransfer.files).filter(f => f.type.startsWith('image/'));
  renderPendingList();
  document.getElementById('upload-all-btn').style.display =
    _pendingFiles.length > 0 ? '' : 'none';
}

function renderPendingList() {
  document.getElementById('multi-upload-list').innerHTML = _pendingFiles.map((f, i) => `
    <div style="display:flex;align-items:center;gap:10px;padding:8px 12px;background:var(--surface2);border-radius:8px">
      <span style="font-size:13px;color:var(--text);flex:1">${f.name}</span>
      <span style="font-size:11px;color:var(--muted)">${(f.size/1024).toFixed(0)} KB</span>
    </div>`).join('');
}

async function uploadAllPendingImages(productId, productName) {
  if (_pendingFiles.length === 0) return;
  const btn = document.getElementById('upload-all-btn');
  btn.disabled = true; btn.textContent = 'Uploading…';

  let successCount = 0;
  for (const file of _pendingFiles) {
    try {
      const url = await uploadProductImage(file);
      await API.addProductImage(productId, url);
      successCount++;
    } catch (err) {
      document.getElementById('img-mgr-err').innerHTML =
        `<div class="alert alert-error">Failed to upload ${file.name}: ${err.message}</div>`;
    }
  }

  _pendingFiles = [];
  toast(`${successCount} image(s) uploaded!`, 'success');
  await refreshImageManager(productId, productName);
}

async function setProductImagePrimary(imageId, productId, productName) {
  try {
    await API.setProductImagePrimary(imageId);
    await refreshImageManager(productId, productName);
  } catch (err) { toast(err.message, 'error'); }
}

async function deleteProductImage(imageId, productId, productName) {
  try {
    await API.deleteProductImage(imageId);
    toast('Image deleted.', 'success');
    await refreshImageManager(productId, productName);
  } catch (err) { toast(err.message, 'error'); }
}
