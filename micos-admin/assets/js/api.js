/**
 * api.js — Central API service
 * Integrated with micos-bikeshop-api v2
 */
const API = (() => {
  const BASE_URL = 'https://capstone-production-6d44.up.railway.app/api';
  const TOKEN_KEY = 'admin_token';

  function getToken() {
    return localStorage.getItem(TOKEN_KEY);
  }

  async function request(method, path, body = null) {
    const headers = { 'Content-Type': 'application/json' };
    const token   = getToken();
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const options = { method, headers };
    if (body && method !== 'GET' && method !== 'DELETE') {
      options.body = JSON.stringify(body);
    }

    // 10-second timeout via AbortController
    const controller = new AbortController();
    const timeout    = setTimeout(() => controller.abort(), 10000);

    let res;
    try {
      res = await fetch(BASE_URL + path, { ...options, signal: controller.signal });
    } catch (err) {
      if (err.name === 'AbortError') throw new Error('Request timed out after 10 seconds.');
      throw new Error('Network error: could not reach the server.');
    } finally {
      clearTimeout(timeout);
    }

    const contentType = res.headers.get('content-type');
    const data = (contentType && contentType.includes('application/json'))
      ? await res.json().catch(() => ({}))
      : {};

    // 401 — clear session and show login (SPA — do NOT redirect to a separate page)
    if (res.status === 401) {
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem('admin_info');
      if (typeof Auth   !== 'undefined') Auth.clear();
      if (typeof Router !== 'undefined') Router.showLogin();
      throw new Error(data.error || 'Session expired. Please log in again.');
    }

    if (!res.ok) {
      throw new Error(data.error || `Request failed with status ${res.status}`);
    }

    return data;
  }

  return { BASE_URL,
    // ── Auth ──────────────────────────────────────────────────────────────────
    adminLogin: (body) => request('POST', '/auth/admin/login', body),

     imgUrl: (path) => {
      if (!path) return '';
      if (path.startsWith('http')) return path;
      const clean = path.startsWith('/') ? path.slice(1) : path;
      return `${BASE_URL.replace('/api', '')}/${clean}`;
    },

    // ── Dashboard ─────────────────────────────────────────────────────────────
    getDashboard: () => request('GET', '/admin/dashboard'),

    // ── Products ──────────────────────────────────────────────────────────────
   getProducts:  (q = '')         => request('GET',  `/products${q}`),
    getProduct:   (id)             => request('GET',  `/products/${id}`),
    createProduct:(body)           => request('POST', '/products', body),
    updateProduct:(id, body)       => request('PUT',  `/products/${id}`, body),
    deleteProduct:(id)             => request('DELETE',`/products/${id}`),
   unarchiveProduct: (id) => request('PUT', `/products/${id}/unarchive`),

   // ── Product Images ────────────────────────────────────────────────────────
    getProductImages:       (pid)      => request('GET',    `/products/${pid}/images`),
    addProductImage:        (pid, url) => request('POST',   `/products/${pid}/images`, { image_url: url }),
    setProductImagePrimary: (id)       => request('PUT',    `/product-images/${id}/set-primary`),
    deleteProductImage:     (id)       => request('DELETE', `/product-images/${id}`),
    // ── AR Models ─────────────────────────────────────────────────────────────
    getARModel:    (productId)    => request('GET',    `/products/${productId}/ar-model`),
    saveARModel:   (productId, b) => request('POST',   `/products/${productId}/ar-model`, b),
    updateARModel: (id, body)     => request('PUT',    `/ar-models/${id}`, body),
    deleteARModel: (id)           => request('DELETE', `/ar-models/${id}`),

    // ── Categories ────────────────────────────────────────────────────────────
    getCategories:  ()           => request('GET',    '/categories'),
    createCategory: (body)       => request('POST',   '/categories', body),
    updateCategory: (id, body)   => request('PUT',    `/categories/${id}`, body),
    deleteCategory: (id)         => request('DELETE', `/categories/${id}`),

    // ── Brands ────────────────────────────────────────────────────────────────
    getBrands:    ()           => request('GET',    '/brands'),
    createBrand:  (body)       => request('POST',   '/brands', body),
    updateBrand:  (id, body)   => request('PUT',    `/brands/${id}`, body),
    deleteBrand:  (id)         => request('DELETE', `/brands/${id}`),

    // ── Orders ────────────────────────────────────────────────────────────────
    // params: { status, payment_status }
    getAdminOrders:    (params = {}) => request('GET', '/admin/orders?' + new URLSearchParams(params)),
    updateOrderStatus: (id, body)    => request('PUT', `/orders/${id}/status`, body),
    confirmPayment:    (id)          => request('PUT', `/orders/${id}/confirm-payment`),
    
    // ── Users ─────────────────────────────────────────────────────────────────
    // params: { search }
    getUsers: (params = {}) => request('GET', '/admin/users?' + new URLSearchParams(params)),

    // ── Inventory ─────────────────────────────────────────────────────────────
    getInventory:     ()             => request('GET',  '/admin/inventory'),
    // params: { product_id, change_type }
    getInventoryLogs: (params = {})  => request('GET',  '/admin/inventory/logs?' + new URLSearchParams(params)),
    logInventory:     (body)         => request('POST', '/admin/inventory/log', body),
    getAdminSuppliers: () => request('GET', '/admin/suppliers'),
    createSupplier: (body) => request('POST', '/admin/suppliers', body),
    updateSupplier: (id, body) => request('PUT', `/admin/suppliers/${id}`, body),
    deleteSupplier: (id) => request('DELETE', `/admin/suppliers/${id}`),
    restoreSupplier: (id) => request('PUT', `/admin/suppliers/${id}/restore`),
    getAnalytics: (params = {}) => request('GET', '/admin/analytics?' + new URLSearchParams(params)),

    // ── Reviews ───────────────────────────────────────────────────────────────
    getAdminReviews:   ()    => request('GET',    '/admin/reviews'),
    getProductReviews: (id)  => request('GET',    `/products/${id}/reviews`),
    deleteReview:      (id)  => request('DELETE', `/reviews/${id}`),

    getVariants:    (productId)      => request('GET',  `/products/${productId}/variants`),
    getVariant:     (id)             => request('GET',  `/variants/${id}`),
    createVariant:  (productId, body) => request('POST', `/products/${productId}/variants`, body),
    updateVariant:  (id, body)       => request('PUT',  `/variants/${id}`, body),
    deleteVariant:  (id)             => request('DELETE', `/variants/${id}`),
    restoreVariant: (id)             => request('PUT',  `/variants/${id}/restore`),
    getVariantARModel:    (id)       => request('GET',  `/variants/${id}/ar-model`),
    saveVariantARModel:   (id, body) => request('POST', `/variants/${id}/ar-model`, body),
    
   
    // ── Messages ──────────────────────────────────────────────────────────────
    getMessages: ()       => request('GET',  '/admin/messages'),
    getThread:   (userId) => request('GET',  `/admin/messages/${userId}`),
    sendMessage: (body)   => request('POST', '/admin/messages', body),
    markMsgRead: (id)     => request('PUT',  `/messages/${id}/read`),

    // ── Shop ──────────────────────────────────────────────────────────────────
    getShop:    ()     => request('GET', '/admin/shop'),
    updateShop: (body) => request('PUT', '/admin/shop', body),
  };
})();

// ── Image URL helper ──────────────────────────────────────────────────────────
// Usage: imgUrl(product.image) or imgUrl(brand.logo)
const imgUrl = (path) => {
  if (!path) return '';
  if (path.startsWith('http')) return path;
  const clean = path.startsWith('/') ? path.slice(1) : path;
  return `${API.BASE_URL.replace('/api', '')}/${clean}`;
};