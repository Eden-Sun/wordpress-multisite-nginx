# wordpress-nginx-compose

Production-ready WordPress Multisite with Nginx, PHP-FPM, and MariaDB.

## Stack

- **WordPress**: FPM Debian (FastCGI Process Manager with FFI support)
- **PHP**: 8.3.27 (with FFI extension enabled for Go interop)
- **Web Server**: Nginx Alpine (configured for Multisite subdirectory)
- **Database**: MariaDB (faster than MySQL)
- **CLI**: WP-CLI (WordPress command-line interface)

## Why This Setup?

- **Nginx + PHP-FPM**: Better performance than Apache + mod_php
- **Multisite Subdirectory Support**: Proper URL rewriting for `/site-name/wp-admin/`
- **Single Config File**: No nested directories, just `nginx.conf` in root
- **External Volume**: Database persists independently of container lifecycle

## Quick Start

```bash
docker compose up -d
```

Access WordPress at `http://your-server-ip/`

## Architecture

```
wordpress-nginx-compose/
├── docker-compose.yml      # Service orchestration
├── nginx.conf              # Nginx with Multisite rewrite rules
├── wp-app/                 # WordPress files
└── .gitignore
```

### Key Nginx Configuration

The `nginx.conf` includes critical rewrites for WordPress Multisite subdirectory mode:

```nginx
if (!-e $request_filename) {
    rewrite ^/[_0-9a-zA-Z-]+(/wp-.*) $1 last;
    rewrite ^/[_0-9a-zA-Z-]+(/.*\.php) $1 last;
}
```

This maps `/site-name/wp-login.php` → `/wp-login.php` while preserving site context.

## Services

### MariaDB
```yaml
environment:
  MYSQL_ROOT_PASSWORD: root
  MYSQL_DATABASE: wordpress
  MYSQL_USER: wordpress_user
  MYSQL_PASSWORD: wordpress_pass
```

### WordPress
- Connects to MariaDB on port 3306
- Mounts `wp-app/` for persistent files
- Uses FPM on port 9000 (FastCGI)

### Nginx
- Listens on host IP:80
- Proxies PHP requests to WordPress container
- Serves static files directly

### WP-CLI
```bash
# Core commands
docker compose run --rm wpcli core version
docker compose run --rm wpcli core update

# Plugin management
docker compose run --rm wpcli plugin list
docker compose run --rm wpcli plugin install <plugin-name> --activate

# User management
docker compose run --rm wpcli user list
docker compose run --rm wpcli user create username email@example.com --role=administrator
docker compose run --rm wpcli user add-role <user-id> administrator

# Multisite: Super Admin management (required for plugin access)
docker compose run --rm wpcli super-admin list
docker compose run --rm wpcli super-admin add <username>
docker compose run --rm wpcli super-admin remove <username>
```

**Note**: In Multisite mode, only Super Admins can manage plugins. Regular site administrators need to be promoted to Super Admin to access plugin management.

## Multisite Setup

If enabling WordPress Multisite:

1. Add to `wp-config.php`:
```php
define('WP_ALLOW_MULTISITE', true);
```

2. After network setup, add:
```php
define('MULTISITE', true);
define('SUBDOMAIN_INSTALL', false);
define('DOMAIN_CURRENT_SITE', 'your-server-ip');
define('PATH_CURRENT_SITE', '/');
define('SITE_ID_CURRENT_SITE', 1);
define('BLOG_ID_CURRENT_SITE', 1);

// Cookie configuration
define('COOKIE_DOMAIN', '');
define('ADMIN_COOKIE_PATH', '/');
define('COOKIEPATH', '/');
define('SITECOOKIEPATH', '/');
```

## Database Management

### Import Database
```bash
docker exec -i mariadb mysql -uroot -proot wordpress < backup.sql
```

### Export Database
```bash
docker exec mariadb mysqldump -uroot -proot wordpress > backup.sql
```

## Troubleshooting

### Child Site wp-admin Redirect Loop
- **Cause**: Missing Multisite URL rewrites in Nginx
- **Fix**: Ensure `nginx.conf` includes the rewrite rules shown above

### wp-login.php Returns 404
- **Cause**: Nginx not routing subdirectory URLs to root PHP files
- **Fix**: Check the `rewrite` rules in `nginx.conf`

### Database Connection Errors
- **Cause**: WordPress container starting before MariaDB is ready
- **Fix**: Wait 5-10 seconds, or add healthcheck to `docker-compose.yml`

### FFI Extension Support

The WordPress container includes PHP FFI (Foreign Function Interface) extension for Go/C interoperability.

**Verify FFI is enabled:**
```bash
docker exec wordpress php -m | grep FFI
# Output: FFI
```

**Test FFI functionality:**
```bash
# Basic test
docker exec wordpress php -r "var_dump(extension_loaded('FFI'));"

# Test with C definitions
docker exec wordpress php -r "
  \$ffi = FFI::cdef('int abs(int);', 'libc.so.6');
  echo 'FFI Test: ' . \$ffi->abs(-42) . PHP_EOL;
"

# Test with WordPress loaded
docker exec wordpress php -r "
  require('/var/www/html/wp-load.php');
  echo 'FFI in WordPress: ' . (extension_loaded('FFI') ? 'ENABLED' : 'DISABLED');
"
```

**Important Notes:**
- FFI is available in the `wordpress` container (Debian-based)
- FFI is **NOT** available in `wpcli` container (uses different image)
- Use `docker exec wordpress` for FFI operations, not `docker compose run wpcli`
- If you modify the Dockerfile, rebuild with: `docker compose build wordpress`

**Why Debian instead of Alpine?**
- Alpine Linux (musl libc) has FFI stability issues causing segmentation faults
- Debian (glibc) provides stable FFI support without crashes
- Minimal configuration required - just install the extension

## Production Considerations

- Change default passwords in `docker-compose.yml`
- Use environment variables instead of hardcoded credentials
- Add SSL/TLS termination (Let's Encrypt)
- Configure backup strategy for `wp-app/` and database
- Set proper file permissions on `wp-app/`

## Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Restart Nginx after config change
docker restart nginx

# Access WordPress container shell
docker exec -it wordpress sh

# Access database
docker exec -it mariadb mysql -uroot -proot wordpress
```

## License

MIT License - See LICENSE file for details
