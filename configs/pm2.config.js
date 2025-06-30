/**
 * PM2 Configuration File
 * ---------------------
 * This file defines the applications that PM2 should manage.
 *
 * Common Options:
 * - name: Unique identifier for the app
 * - script: Entry point file
 * - cwd: Working directory
 * - instances: Number of instances (use 'max' for cluster mode)
 * - autorestart: Restart on crash
 * - watch: Enable file watching
 * - max_memory_restart: Restart if memory exceeds limit
 * - env: Environment variables
 */
module.exports = {
    apps: [
        // PM2 process configurations
    ],
  };