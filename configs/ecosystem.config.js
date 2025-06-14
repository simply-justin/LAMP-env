module.exports = {
  apps: [
    {
      name: "billbuilder-ui",
      cwd: "/var/www/billbuilder/billbuilder-ui",
      script: "npm",
      args: "run dev -- --port=3000",
      watch: false,
      env: {
        NODE_ENV: "development",
      },
    },
  ],
};