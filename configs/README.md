# 🛠️ LAMP-env Configuration Guide

This directory contains all configuration files needed for the LAMP-env environment. Each file serves a specific purpose and should be reviewed and customized before running the installation script.

---

## 📚 Table of Contents

- [🛠️ LAMP-env Configuration Guide](#️-lamp-env-configuration-guide)
  - [📚 Table of Contents](#-table-of-contents)
  - [📁 Directory Structure](#-directory-structure)
  - [📦 Project Configuration (`projects.json`)](#-project-configuration-projectsjson)
  - [⚙️ Process Management (`pm2.config.js`)](#️-process-management-pm2configjs)
  - [🌐 Virtual Hosts (`vhosts/`)](#-virtual-hosts-vhosts)
    - [Default Configuration (`environment.conf`)](#default-configuration-environmentconf)
    - [Example: PHP Project with FPM](#example-php-project-with-fpm)
    - [Example: Next.js Project (Node.js) with Apache Proxy](#example-nextjs-project-nodejs-with-apache-proxy)

---

## 📁 Directory Structure

```plaintext
configs/
├── projects.json           # Project repository definitions
├── pm2.config.js           # Node.js process management
└── vhosts/                 # Apache virtual host configurations
    └── environment.conf    # Default vhost settings
```

---

## 📦 Project Configuration (`projects.json`)

This file defines which GitHub repositories will be cloned and set up as part of your environment. Each entry represents a project and specifies where it should be placed.

**Example:**

```json
[
    {
        "org": "acme-corp",
        "repo": "backend-api",
        "target_dir": "/projects"
    },
    {
        "org": "acme-corp",
        "repo": "frontend-app",
        "target_dir": "/projects"
    }
]
```

**Fields:**

- `org`: GitHub organization or username.
- `repo`: Repository name.
- `target_dir`: Local directory path (relative to the `$HOME/projects` directory).

> [!IMPORTANT]
> - The `target_dir` is relative to the `projects` directory created in your user's home.
> - For example, `/example-dir/project-dir` resolves to `$HOME/projects/example-dir/project-dir`.
> - Make sure you have access to the repositories (private repos require a valid GitHub token).

---

## ⚙️ Process Management (`pm2.config.js`)

This file configures Node.js applications to be managed by [PM2](https://pm2.keymetrics.io/), a production process manager for Node.js apps. Each entry in the `apps` array defines a process to run.

**Example:**

```js
module.exports = {
    apps: [
        {
            name: "example-pm2",
            cwd: "/var/www/example-pm2",
            script: "npm",
            args: "run dev -- --port=3000",
            watch: false,
            env: {
                NODE_ENV: "development"
            }
        }
    ]
};
```

**Common PM2 Options:**

- `name`: Unique identifier for the process.
- `cwd`: Working directory (**use absolute paths**).
- `script`: Entry point file or command (e.g., `npm`).
- `args`: Arguments to pass to the script (e.g., `run dev`).
- `watch`: Enable file watching for auto-restart (set to `true` for development).
- `env`: Environment variables.

> [!IMPORTANT]
> - All paths in PM2 configurations should be absolute.
> - Ensure the `cwd` matches the deployed location of your Node.js project.

---

## 🌐 Virtual Hosts (`vhosts/`)

This directory contains Apache virtual host configurations for your projects. Each `.conf` file defines how Apache should serve a specific project or service.

### Default Configuration (`environment.conf`)

This file provides a base template for virtual hosts. You can include or extend it in your project-specific configs.

```apache
<VirtualHost *:80>
    ServerName redis.local

    ProxyPreserveHost On
    ProxyRequests Off

    ProxyPass        / http://localhost:8081/
    ProxyPassReverse / http://localhost:8081/

    ErrorLog  /var/log/apache2/redis.error.log
    CustomLog /var/log/apache2/redis.access.log combined
</VirtualHost>

<VirtualHost *:80>
    ServerName rabbitmq.local

    ProxyPreserveHost On
    ProxyRequests Off

    ProxyPass        / http://localhost:8081/
    ProxyPassReverse / http://localhost:8081/

    ErrorLog  /var/log/apache2/redis.error.log
    CustomLog /var/log/apache2/redis.access.log combined
</VirtualHost>
```

> [!TIP]
> Use this as a starting point for your own `.conf` files.

---

### Example: PHP Project with FPM

This configuration serves a PHP project using PHP-FPM for optimal performance.

```apache
<VirtualHost *:80>
    ServerName example-php.local
    DocumentRoot /var/www/example-php/public
    SetEnv APPLICATION_ENV "development"

    # PHP-FPM backend
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php8.4-fpm.sock|fcgi://localhost/"
    </FilesMatch>

    # Directory settings for your project
    <Directory /var/www/example-php/public>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    # Logging
    ErrorLog  /var/log/apache2/example-php.error.log
    CustomLog /var/log/apache2/example-php.access.log combined
</VirtualHost>
```

**Explanation:**

- `ServerName`: The local domain for your project (add this to your hosts file).
- `DocumentRoot`: The public directory to serve.
- `SetHandler`: Uses PHP-FPM via a Unix socket for PHP files.
- `<Directory>`: Sets permissions and overrides for the project directory.
- Logging is set up for easier debugging.

---

### Example: Next.js Project (Node.js) with Apache Proxy

This configuration proxies requests to a Next.js app running on a local port (e.g., 3000). It also supports WebSocket connections for fast refresh.

```apache
<VirtualHost *:80>
    ServerName example-nextjs.local

    ProxyPreserveHost On
    ProxyRequests Off

    # Websocket support for Next.js fast refresh.
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*) ws://localhost:3000/$1 [P,L]

    RewriteCond %{HTTP:Upgrade} !=websocket [NC]
    RewriteRule /(.*) http://localhost:3000/$1 [P,L]

    # Fallback proxy for non-rewritten requests (safety net)
    ProxyPass        / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/

    # Logging
    ErrorLog  /var/log/apache2/example-nextjs.error.log
    CustomLog /var/log/apache2/example-nextjs.access.log combined
</VirtualHost>
```

**Explanation:**

- `ServerName`: The local domain for your Next.js app.
- `RewriteEngine` and `RewriteCond`: Enable WebSocket proxying for hot reload/fast refresh.
- `ProxyPass`/`ProxyPassReverse`: Forward all other traffic to the Next.js server.
- Logging is set up for easier debugging.

> [!IMPORTANT]
> - Virtual host configurations must use the `.conf` extension.
> - Project domains in virtual hosts must match your hosts file entries.
> - All paths in virtual host configurations should be absolute.
> - Make sure your Next.js app is running on the port specified (default: 3000).
