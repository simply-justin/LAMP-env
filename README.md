# 🚀 LAMP-env

**LAMP-env** is a one-command, automated local development environment for the LAMP stack (Linux, Apache, MariaDB, PHP) with optional Redis and RabbitMQ integration. It handles everything from system dependencies to project configuration, so you can start coding in minutes.

## 🧩 Supported Variants

- **Basic LAMP** (`lamp-env`): Apache, MariaDB, PHP, Node.js
- **LAMP + Redis** (`lamp-env-redis`): Basic LAMP + Redis cache server
- **LAMP + RabbitMQ** (`lamp-env-rabbitmq`): Basic LAMP + RabbitMQ message broker
- **Full Stack** (`lamp-env-full`): All components combined

---

## 📚 Table of Contents

- [🚀 LAMP-env](#-lamp-env)
  - [🧩 Supported Variants](#-supported-variants)
  - [📚 Table of Contents](#-table-of-contents)
  - [⚡️ Quick Start](#️-quick-start)
    - [1️⃣ Prerequisites](#1️⃣-prerequisites)
    - [2️⃣ Clone the Repository](#2️⃣-clone-the-repository)
    - [3️⃣ Configure Your Environment](#3️⃣-configure-your-environment)
    - [4️⃣ Update Your Hosts File](#4️⃣-update-your-hosts-file)
    - [5️⃣ Install](#5️⃣-install)
  - [🛠️ What Gets Installed](#️-what-gets-installed)
  - [📄 License](#-license)

---

## ⚡️ Quick Start

### 1️⃣ Prerequisites

- Ubuntu 22.04 or compatible Debian-based system
- Bash shell
- Sudo privileges
- GitHub personal access token with `repo` scope

### 2️⃣ Clone the Repository

Replace `<GITHUB_TOKEN>` with your personal access token and choose your variant:

> **Tip:** Always clone into your user's home directory and use `LAMP-env` as the folder name.

```bash
# Basic LAMP
git clone -b lamp-env https://<GITHUB_TOKEN>@github.com/simply-justin/LAMP-env.git

# LAMP + Redis
git clone -b lamp-env-redis https://<GITHUB_TOKEN>@github.com/simply-justin/LAMP-env.git

# LAMP + RabbitMQ
git clone -b lamp-env-rabbitmq https://<GITHUB_TOKEN>@github.com/simply-justin/LAMP-env.git

# LAMP + Redis + RabbitMQ
git clone -b lamp-env-full https://<GITHUB_TOKEN>@github.com/simply-justin/LAMP-env.git
```

### 3️⃣ Configure Your Environment

Before installation, **customize your setup**:

- Edit your projects in `configs/projects.json`
- Adjust PM2 settings in `configs/pm2.config.js`
- Set up virtual hosts in `configs/vhosts/`

➡️ **See the [`configs/README.md`](./configs/README.md) for full configuration details.**

### 4️⃣ Update Your Hosts File

Add these entries to your `hosts` file (`C:\Windows\System32\drivers\etc\hosts` on Windows, `/etc/hosts` on Linux):

| IP        | HOST           |
| --------- | -------------- |
| 127.0.0.1 | `redis.local`    |
| 127.0.0.1 | `rabbitmq.local` |

> Only add entries for the services you plan to use.

### 5️⃣ Install

From the project root, run:

```bash
bash LAMP-env/entry.sh <GITHUB_TOKEN> [options]
```

**Options:**

- `--php <versions>` : Comma-separated PHP versions (default: 8.3)
- `--package-manager <pm>` : Node.js package manager (default: npm)
- `--debug` : Enable verbose logging
- `--exclude` : Skip specific setup scripts
- `--only` : Run only specific setup scripts

**Examples:**

```bash
# Install PHP 8.1 and 8.2
bash LAMP-env/entry.sh <GITHUB_TOKEN> --php 8.1,8.2

# Use pnpm as Node.js package manager
bash LAMP-env/entry.sh <GITHUB_TOKEN> --package-manager pnpm
```

---

## 🛠️ What Gets Installed

- **Web Server:** Apache2 with virtual hosts
- **Database:** MariaDB
- **PHP:** Multiple versions with common extensions
- **Node.js:** Latest LTS with PM2 process manager
- **Optional:**
  - Redis cache server and GUI
  - RabbitMQ message broker and management interface

---

## 📄 License

MIT License