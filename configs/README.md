# Configuration Files

This directory contains configuration files for the development environment.

## Files

### processes.json

Defines repositories to be cloned and set up:

```json
[
  {
    "org": "myorg",
    "repo": "myproject",
    "target_dir": "/dev/projects"
  }
]
```

### processes.config.js

PM2 process configuration:

```javascript
module.exports = {
  apps: [{
    name: "myapp",
    script: "./app.js",
    instances: "max",
    exec_mode: "cluster",
    env: {
      NODE_ENV: "development"
    }
  }]
}
```

## Virtual Hosts

See [vhosts/README.md](vhosts/README.md) for Apache virtual host configuration details.

## Best Practices

1. Always backup existing configurations before making changes
2. Use descriptive names for configuration files
3. Keep sensitive information out of configuration files
4. Document any custom configurations
