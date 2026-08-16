/**
 * router.js — Hash-based SPA router
 */
const Router = (() => {
  const routes = {
  '/dashboard':     pageDashboard,
  '/orders':        pageOrders,
  '/inventory':     pageInventory,
  '/catalog':       pageCatalog,
  '/customers':     pageCustomers,
  '/analytics':     pageAnalytics,
  '/messages':      pageMessages,
  '/notifications': pageNotifications,
  '/settings':      pageSettings,
};

  function getPath() {
    const hash = window.location.hash.replace('#', '') || '/dashboard';
    return hash.split('?')[0];
  }

  function navigate(path) {
    window.location.hash = path;
  }

  async function resolve() {
    if (!Auth.isLoggedIn()) {
      showLogin();
      return;
    }

    showApp();
    const path    = getPath();
    const handler = routes[path] || routes['/dashboard'];
    const container = document.getElementById('page-container');

    // Update active nav
    document.querySelectorAll('.nav-item').forEach(a => {
      a.classList.toggle('active', a.dataset.page === path.replace('/', ''));
    });

   // Clean up listeners when navigating away
     if (typeof _ordersListener === 'function') { _ordersListener(); _ordersListener = null; }
     if (typeof _dashListener === 'function') { _dashListener(); _dashListener = null; }

    container.innerHTML = `<div class="spinner-wrap"><div class="spinner"></div><p>Loading…</p></div>`;
    await handler(container);
  }

  function showLogin() {
    document.getElementById('login-screen').classList.remove('hidden');
    document.getElementById('app-shell').classList.add('hidden');
  }

  function showApp() {
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('app-shell').classList.remove('hidden');

    const admin = Auth.getAdmin();
    if (admin) {
      document.getElementById('admin-name').textContent = admin.name || admin.username;
      document.getElementById('admin-initials').textContent =
        (admin.name || admin.username || 'A').split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase();
    }
  }

  window.addEventListener('hashchange', resolve);

  return { resolve, navigate, showLogin, showApp };
})();
