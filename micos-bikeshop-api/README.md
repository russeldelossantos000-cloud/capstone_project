# Mico's Bike Shop — PHP REST API

Built with **Slim 4**, **JWT Auth**, and **PDO/MySQL**.

---

## 📁 Project Structure

```
micos-bikeshop-api/
├── public/
│   ├── index.php          # Entry point
│   └── .htaccess          # Apache rewrite rules
├── src/
│   ├── Config/
│   │   └── Database.php   # PDO singleton
│   ├── Middleware/
│   │   ├── AuthMiddleware.php   # JWT user guard
│   │   └── AdminMiddleware.php  # JWT admin guard
│   ├── Controllers/
│   │   ├── AuthController.php
│   │   ├── UserController.php
│   │   ├── ProductController.php
│   │   ├── CategoryController.php
│   │   ├── BrandController.php
│   │   ├── CartController.php
│   │   ├── OrderController.php
│   │   ├── MessageController.php
│   │   ├── CustomizationController.php
│   │   ├── ARModelController.php
│   │   └── AdminController.php
│   └── Routes/
│       └── routes.php
├── composer.json
├── .env.example
└── README.md
```

---

## ⚙️ Setup

### 1. Install dependencies
```bash
composer install
```

### 2. Configure environment
```bash
cp .env.example .env
```
Edit `.env` with your DB credentials and a strong `JWT_SECRET`.

### 3. Import the database
Use your existing `micos_bikeshop_db` schema in MySQL/phpMyAdmin.

### 4. Run the server
```bash
# Development (built-in PHP server)
composer start

# Production: point Apache/Nginx document root to /public
```

### Apache Virtual Host example
```apacheconf
<VirtualHost *:80>
    DocumentRoot /var/www/micos-bikeshop-api/public
    <Directory /var/www/micos-bikeshop-api/public>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

---

## 🔐 Authentication

All protected routes require:
```
Authorization: Bearer <token>
```

Tokens are returned from `/api/auth/login` and `/api/auth/register`.
Admin tokens come from `/api/auth/admin/login`.

---

## 📡 API Endpoints

### 🔑 Auth
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| POST | `/api/auth/register` | email, password, full_name, phone?, address? | Public |
| POST | `/api/auth/login` | email, password | Public |
| POST | `/api/auth/admin/login` | username, password | Public |

---

### 👤 Users
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| GET | `/api/users/me` | — | User |
| PUT | `/api/users/me` | full_name?, phone?, address?, password? | User |
| DELETE | `/api/users/me` | — | User |

---

### 🚲 Products
| Method | Endpoint | Body / Query | Auth |
|--------|----------|-------------|------|
| GET | `/api/products` | ?search=&category_id=&brand_id=&is_customizable= | Public |
| GET | `/api/products/{id}` | — | Public |
| POST | `/api/products` | product_name, price, stock, category_id, description?, image?, is_customizable?, brand_id? | Admin |
| PUT | `/api/products/{id}` | any product fields | Admin |
| DELETE | `/api/products/{id}` | — | Admin |

---

### 🏷️ Categories
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| GET | `/api/categories` | — | Public |
| GET | `/api/categories/{id}` | — | Public |
| POST | `/api/categories` | category_name | Admin |
| PUT | `/api/categories/{id}` | category_name | Admin |
| DELETE | `/api/categories/{id}` | — | Admin |

---

### 🏭 Brands
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| GET | `/api/brands` | — | Public |
| GET | `/api/brands/{id}` | — | Public |
| POST | `/api/brands` | brand_name, logo? | Admin |
| PUT | `/api/brands/{id}` | brand_name?, logo? | Admin |
| DELETE | `/api/brands/{id}` | — | Admin |

---

### 🛒 Cart
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| GET | `/api/cart` | — | User |
| POST | `/api/cart/items` | product_id, quantity | User |
| PUT | `/api/cart/items/{id}` | quantity | User |
| DELETE | `/api/cart/items/{id}` | — | User |
| DELETE | `/api/cart` | — | User |

---

### 📦 Orders
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| GET | `/api/orders` | — | User |
| GET | `/api/orders/{id}` | — | User |
| POST | `/api/orders` | payment_method, customizations?[product_id][option_id] | User |
| PUT | `/api/orders/{id}/status` | status?, payment_status? | Admin |

**Valid `status` values:** `pending`, `processing`, `shipped`, `delivered`, `cancelled`  
**Valid `payment_status` values:** `unpaid`, `paid`, `refunded`

---

### 💬 Messages
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| GET | `/api/messages` | — | User |
| GET | `/api/messages/{userId}` | — | User |
| POST | `/api/messages` | receiver_id, message | User |
| PUT | `/api/messages/{id}/read` | — | User |

---

### 🎨 Customizations
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| GET | `/api/customizations` | — | Public |
| GET | `/api/customizations/{id}` | — | Public |
| GET | `/api/customizations/{id}/options` | — | Public |
| POST | `/api/customizations` | name | Admin |
| PUT | `/api/customizations/{id}` | name | Admin |
| DELETE | `/api/customizations/{id}` | — | Admin |
| POST | `/api/customizations/{id}/options` | option_name, additional_price? | Admin |
| PUT | `/api/customization-options/{id}` | option_name?, additional_price? | Admin |
| DELETE | `/api/customization-options/{id}` | — | Admin |

---

### 🥽 AR Models
| Method | Endpoint | Body | Auth |
|--------|----------|------|------|
| GET | `/api/products/{id}/ar-model` | — | Public |
| POST | `/api/products/{id}/ar-model` | model_file, scale? | Admin |
| PUT | `/api/ar-models/{id}` | model_file?, scale? | Admin |
| DELETE | `/api/ar-models/{id}` | — | Admin |

---

### 🛠️ Admin Panel
| Method | Endpoint | Query | Auth |
|--------|----------|-------|------|
| GET | `/api/admin/dashboard` | — | Admin |
| GET | `/api/admin/users` | ?search= | Admin |
| GET | `/api/admin/orders` | ?status=&payment_status= | Admin |
| GET | `/api/admin/inventory` | — | Admin |
| GET | `/api/admin/inventory/logs` | ?product_id=&change_type= | Admin |
| POST | `/api/admin/inventory/log` | product_id, change_type (IN/OUT), quantity, reason? | Admin |
| GET | `/api/admin/shop` | — | Admin |
| PUT | `/api/admin/shop` | name?, address?, contact_number?, email? | Admin |

---

## 📬 Example Requests

### Register
```http
POST /api/auth/register
Content-Type: application/json

{
  "email": "juan@example.com",
  "password": "secret123",
  "full_name": "Juan dela Cruz",
  "phone": "09171234567"
}
```

### Place an Order with Customization
```http
POST /api/orders
Authorization: Bearer <token>
Content-Type: application/json

{
  "payment_method": "gcash",
  "customizations": {
    "3": [1, 4]
  }
}
```
> `"3"` is the `product_id`, `[1, 4]` are `option_id` values from `customization_options`.

### Admin Inventory Log
```http
POST /api/admin/inventory/log
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "product_id": 5,
  "change_type": "IN",
  "quantity": 20,
  "reason": "Restocked from supplier"
}
```
