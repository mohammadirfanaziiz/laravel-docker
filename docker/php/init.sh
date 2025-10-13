#!/bin/bash
set -e

cd /var/www/html

# ==== Instalasi Laravel jika belum ada ====
if [ ! -f composer.json ]; then
  echo "Laravel belum ada, instalasi dimulai..."
  composer create-project laravel/laravel="10.*" . #sesuaikan ya cuy yang dibutuhin,kecuali lu udah di export
else
  echo "Laravel sudah terpasang, skip instalasi."
fi

# ==== Sesuaikan file .env dengan environment dari Docker ====
echo "Menyesuaikan .env dengan variabel environment..."

if [ ! -f .env ]; then
  echo "Membuat file .env dari .env.example..."
  cp .env.example .env
fi

sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=${DB_CONNECTION}/" .env
sed -i "s/^#* *DB_HOST=.*/DB_HOST=${DB_HOST}/" .env
sed -i "s/^#* *DB_PORT=.*/DB_PORT=${DB_PORT}/" .env
sed -i "s/^#* *DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE}/" .env
sed -i "s/^#* *DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME}/" .env
sed -i "s/^#* *DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" .env

echo "Konfigurasi database saat ini:"
grep "^DB_" .env || true

# ==== Atur permission ====
echo "Mengatur hak akses direktori storage dan bootstrap/cache..."
mkdir -p storage/logs bootstrap/cache
touch storage/logs/laravel.log
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# ==== Ambil environment Laravel ====
APP_ENV=$(grep ^APP_ENV= .env | cut -d '=' -f2 | tr -d '\r')
if [[ -z "$APP_ENV" ]]; then
    APP_ENV=local
fi
echo "Environment Laravel: $APP_ENV"

# ==== Install & Optimisasi ====
echo "Menjalankan Composer..."
composer validate --strict || true
composer install --optimize-autoloader --no-dev

# ==== Tunggu Database Siap ====
echo "Menunggu database siap di ${DB_HOST}:${DB_PORT}..."

# Coba pakai mysqladmin ping daripada nc, lebih akurat di container
until php -r "
try {
    \$pdo = new PDO('mysql:host=${DB_HOST};port=${DB_PORT}', '${DB_USERNAME}', '${DB_PASSWORD}');
    echo 'Database siap!';
} catch (Exception \$e) {
    exit(1);
}
"; do
    echo "Database belum siap, tunggu 5 detik..."
    sleep 5
done

echo "Database siap, lanjutkan..."

# ==== Generate key (jika belum ada) ====
if ! grep -q "APP_KEY=" .env || [ -z "$(grep 'APP_KEY=' .env | cut -d '=' -f2)" ]; then
  echo "Membuat APP_KEY..."
  php artisan key:generate
fi

# ==== Migrasi database ====
echo "Menjalankan migrasi database..."
php artisan migrate || echo "Migrasi gagal, mungkin database belum siap sepenuhnya."

# ==== Cache & Clear sesuai environment ====
if [ "$APP_ENV" = "production" ]; then
    echo "Mode production: menjalankan caching..."
    php artisan config:clear
    php artisan cache:clear
    php artisan route:clear
    php artisan view:clear

    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
else
    echo "Mode development: membersihkan cache..."
    php artisan config:clear
    php artisan cache:clear
    php artisan route:clear
    php artisan view:clear
fi

# ==== Jalankan Apache ====
echo "Menjalankan Apache..."
exec apache2-foreground
