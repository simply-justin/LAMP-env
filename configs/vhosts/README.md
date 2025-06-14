# Apache Virtual Host Configurations

Configuration files for Apache virtual hosts. Each file should have a `.conf` extension.

## Naming Convention

- `project-name.conf` - Standard configuration
- `project-name-ssl.conf` - SSL-enabled configuration
- `project-name-dev.conf` - Development configuration

## Templates

### Basic Virtual Host

```apache
<VirtualHost *:80>
    ServerName example.local
    ServerAlias www.example.local
    ServerAdmin webmaster@example.local
    DocumentRoot /var/www/example
    
    <Directory /var/www/example>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/example-error.log
    CustomLog ${APACHE_LOG_DIR}/example-access.log combined
</VirtualHost>
```

### SSL Virtual Host

```apache
<VirtualHost *:443>
    ServerName example.local
    ServerAlias www.example.local
    DocumentRoot /var/www/example
    
    <Directory /var/www/example>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/example.crt
    SSLCertificateKeyFile /etc/ssl/private/example.key
    
    ErrorLog ${APACHE_LOG_DIR}/example-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/example-ssl-access.log combined
</VirtualHost>
```

## Common Issues

1. **403 Forbidden**
   - Check directory permissions
   - Verify `Require` directives
   - Check SELinux context

2. **500 Internal Server Error**
   - Check Apache error logs
   - Verify PHP configuration
   - Check file permissions

3. **SSL Issues**
   - Verify certificate paths
   - Check certificate validity
   - Ensure SSL module is enabled
