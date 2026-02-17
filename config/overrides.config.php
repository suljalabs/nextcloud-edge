<?php
$CONFIG = array (
  // 1. Dynamic Database Configuration
  // We parse the DATABASE_URL provided by Hyperdrive
  'dbtype' => 'pgsql',
  'dbname' => getenv('DB_NAME'),
  'dbhost' => getenv('DB_HOST'), // Will be the Hyperdrive local address
  'dbuser' => getenv('DB_USER'),
  'dbpassword' => getenv('DB_PASSWORD'),

  // 2. Trusted Proxies
  // Since traffic comes from the Worker (internal network), we must trust
  // the entire Cloudflare internal range or specific subnets.
  'trusted_proxies' => array(
    '10.0.0.0/8',
    '172.16.0.0/12',
    '192.168.0.0/16',
    '127.0.0.1',
  ),
  'overwriteprotocol' => 'https',
  
  // 3. Object Storage as Primary Storage (FUSE is primary, but this configures Nextcloud to be aware)
  'objectstore' => array(
        'class' => '\\OC\\Files\\ObjectStore\\S3',
        'arguments' => array(
                'bucket' => getenv('R2_BUCKET_NAME'),
                'autocreate' => true,
                'key'    => getenv('AWS_ACCESS_KEY_ID'),
                'secret' => getenv('AWS_SECRET_ACCESS_KEY'),
                'hostname' => getenv('R2_ACCOUNT_ID') . '.r2.cloudflarestorage.com',
                'port' => 443,
                'use_ssl' => true,
                'region' => 'auto',
                // Required for some S3 implementations
                'use_path_style' => true
        ),
  ),
  
  // 4. Redis Configuration (Locking & Caching)
  // 'memcache.local' => '\OC\Memcache\APCu', // Fallback if Redis is network-bound
  'memcache.distributed' => '\OC\Memcache\Redis',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => [
        'host' => getenv('REDIS_HOST'),
        'port' => getenv('REDIS_PORT'),
        'password' => getenv('REDIS_PASSWORD'),
        'timeout' => 1.5,
  ],
);
