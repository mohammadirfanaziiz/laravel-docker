FROM php:8.2-apache

# Install dependency tambahan termasuk netcat
RUN apt-get update && apt-get install -y \
    zip unzip git curl libpng-dev libonig-dev libxml2-dev netcat-traditional \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd \
    && rm -rf /var/lib/apt/lists/*

# Copy composer dari image resmi composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Aktifkan mod_rewrite untuk Laravel
RUN a2enmod rewrite

# Salin konfigurasi Apache
COPY docker/php/apache.conf /etc/apache2/sites-available/000-default.conf

# Salin entrypoint (init.sh)
COPY docker/php/init.sh /usr/local/bin/init.sh

# 🔥 FIX CRLF → otomatis ubah ke LF + bikin executable
RUN sed -i 's/\r$//' /usr/local/bin/init.sh && chmod +x /usr/local/bin/init.sh

# Jalankan init.sh saat container start
ENTRYPOINT ["/usr/local/bin/init.sh"]
