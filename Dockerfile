FROM php:8.3-apache

# 1. Dependencias del sistema y extensiones de PHP requeridas por Moodle
RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev \
    libicu-dev libxml2-dev libsodium-dev unzip git curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd zip intl soap opcache mysqli pdo_mysql sodium exif \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# 2. Composer para dependencias del core
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# 3. Ajustes de PHP recomendados para producción
RUN echo 'max_input_vars = 5000' > /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'upload_max_filesize = 100M' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'post_max_size = 100M' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'memory_limit = 512M' >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo 'zend.exception_ignore_args = On' >> /usr/local/etc/php/conf.d/moodle.ini

# 4. Configurar Apache para servir desde /var/www/html/public con el enrutador /r.php
RUN echo '<VirtualHost *:80>\n\
    ServerAdmin webmaster@localhost\n\
    DocumentRoot /var/www/html/public\n\
    <Directory /var/www/html/public>\n\
        Options -Indexes +FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
        DirectoryIndex index.php\n\
        FallbackResource /r.php\n\
    </Directory>\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

# 5. Descarga de Moodle 5.2 y dependencias
WORKDIR /var/www/html
RUN curl -L -o moodle.tgz https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz \
    && tar -xzf moodle.tgz --strip-components=1 \
    && rm moodle.tgz \
    && composer install --no-dev --classmap-authoritative

# 6. Directorio moodledata y permisos
RUN mkdir -p /var/www/moodledata \
    && chown -R www-data:www-data /var/www/html /var/www/moodledata \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/moodledata

EXPOSE 80
CMD ["apache2-foreground"]
