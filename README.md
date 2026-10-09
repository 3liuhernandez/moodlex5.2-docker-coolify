# Despliegue de Moodle 5.2 en Coolify (Docker & Docker Compose)

Este repositorio contiene la configuración lista para producción para desplegar **Moodle 5.2** sobre **PHP 8.3 Apache** en un VPS gestionado por **Coolify**.

Incluye:
- Todas las extensiones requeridas por Moodle (`intl`, `gd`, `zip`, `soap`, `opcache`, `mysqli`, `sodium`, `exif`).
- Apache configurado para la arquitectura moderna de Moodle 5.x (`DocumentRoot /var/www/html/public` con `FallbackResource /r.php`).
- Parámetros de PHP optimizados (`max_input_vars = 5000`, `upload_max_filesize = 100M`, `memory_limit = 512M`, `zend.exception_ignore_args = On`).
- Instalación automatizada de dependencias del core con **Composer**.
- Almacenamiento persistente con nombres estandarizados para código (`moodle_html`) y datos (`moodle_data`).

---

## 📁 Estructura del Repositorio

Para que Coolify construya la imagen sin incidencias, el repositorio debe contener únicamente estos dos archivos en la raíz:

```text
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### 1. `Dockerfile`

```dockerfile
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

# 5. Descarga de Moodle 5.2 y compilación de dependencias
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
```

### 2. `docker-compose.yml`

```yaml
version: '3.8'

services:
  moodle:
    container_name: moodle_app
    restart: always
    build: .
    volumes:
      - moodle_html:/var/www/html
      - moodle_data:/var/www/moodledata
    ports:
      - "80"

volumes:
  moodle_html:
    name: moodle_html
  moodle_data:
    name: moodle_data
```

---

## 🚀 Paso a Paso: Despliegue en Coolify

### Requisitos Previos
1. Un servidor VPS con **Coolify** instalado y funcionando.
2. Un servidor de base de datos **MariaDB 10.11+** o **MySQL 8.0+** accesible por red.
3. El dominio o subdominio apuntando mediante registro DNS tipo **A** a la IP pública del VPS (ejemplo: `moodle.tudominio.com`).

---

### Paso 1: Preparar la Base de Datos

Conéctate a tu base de datos y ejecuta la creación de la base de datos y el usuario con codificación compatible:

```sql
CREATE DATABASE moodle_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'moodle_user'@'%' IDENTIFIED BY 'TuPasswordSeguro123';
GRANT ALL PRIVILEGES ON moodle_db.* TO 'moodle_user'@'%';
FLUSH PRIVILEGES;
```

---

### Paso 2: Conectar el Repositorio en Coolify

1. Ingresa al panel de control de tu **Coolify**.
2. Entra en tu **Proyecto** y selecciona el **Entorno** deseado (por ejemplo, `production`).
3. Haz clic en **+ New Resource** (o **+ Add Resource**).
4. Selecciona **Public Repository** o **Private Repository (GitHub App / Deploy Key)** según la privacidad de tu repo.
5. Pega la URL del repositorio de Git y haz clic en **Check repository**.
6. Selecciona la rama de despliegue (generalmente `main`).
7. Coolify detectará automáticamente la existencia de `docker-compose.yml` y `Dockerfile`.

---

### Paso 3: Configurar el Dominio

1. En la vista general del servicio recién creado en Coolify, ubica la sección **General**.
2. En el campo **Domains (FQDN)**, escribe la URL de tu plataforma especificando el puerto interno `80`:
   ```text
   https://moodle.tudominio.com:80
   ```
3. Haz clic en **Save** en la sección superior.

---

### Paso 4: Ejecutar el Despliegue (Deploy)

1. En la esquina superior derecha, haz clic en **Deploy**.
2. Ve a la pestaña **Deployments** para observar los registros de construcción en tiempo real:
   - El VPS descargará la imagen base `php:8.3-apache`.
   - Se compilarán las extensiones nativas de PHP y se instalará Composer.
   - Se descargará Moodle 5.2 y se resolverán las dependencias del core.
   - Se crearán y montarán los volúmenes `moodle_html` y `moodle_data`.
3. **Verificación:** Cuando el proceso finalice, el indicador de estado cambiará de rojo/naranja a **verde (`Running`)**.

---

### Paso 5: Finalizar la Instalación Web

Abre en tu navegador la URL asignada:
```text
https://moodle.tudominio.com
```

1. **Selección de rutas:**
   - La dirección web (`wwwroot`) será detectada automáticamente.
   - El directorio de datos (`dataroot`) debe ser: `/var/www/moodledata`.
2. **Conexión a la base de datos:**
   - **Tipo:** MariaDB (o MySQL según corresponda).
   - **Host de la base de datos:** IP o hostname del servidor de BD.
   - **Nombre de la base de datos:** `moodle_db`.
   - **Usuario de la base de datos:** `moodle_user`.
   - **Contraseña:** `TuPasswordSeguro123`.
   - **Puerto:** `3306`.
   - **Socket Unix:** *Dejar completamente en blanco*.
3. **Comprobaciones del entorno:**
   - Todas las extensiones y directivas (`zend.exception_ignore_args`, Composer, Router) aparecerán en verde ("OK").
4. Haz clic en **Continuar** para ejecutar la creación de tablas y finalizar la cuenta administradora.

---

### ⚠️ Parámetro Crítico en `config.php` (Proxy SSL)

Al finalizar la instalación o si configuras `config.php` de forma manual, asegúrate de que el archivo contenga:

```php
$CFG->wwwroot  = 'https://moodle.tudominio.com';
$CFG->sslproxy = true;
```

> **IMPORTANTE:** **NO** agregues `$CFG->reverseproxy = true;`. Coolify utiliza Traefik para gestionar el certificado SSL e interactúa con el contenedor mediante HTTP interno; el parámetro `reverseproxy` causará un error de bloqueo en pantalla (`Reverse proxy enabled so the server cannot be accessed directly`). Con `$CFG->sslproxy = true;` los estilos CSS, scripts y peticiones HTTPS funcionarán con normalidad.
