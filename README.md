# Despliegue de Moodle 5.2 en Coolify (Docker & Docker Compose)

Este repositorio contiene la configuración lista para producción para desplegar **Moodle 5.2** sobre **PHP 8.3 Apache** en un VPS gestionado por **Coolify**.

Incluye:
* Todas las extensiones requeridas por Moodle (`intl`, `gd`, `zip`, `soap`, `opcache`, `mysqli`, `sodium`, `exif`).
* Apache configurado para la arquitectura moderna de Moodle 5.x (`DocumentRoot /var/www/html/public` con `FallbackResource /r.php`).
* Parámetros de PHP optimizados (`max_input_vars = 5000`, `upload_max_filesize = 100M`, `memory_limit = 512M`, `zend.exception_ignore_args = On`).
* Instalación automatizada de dependencias del core con **Composer**.
* Almacenamiento persistente con nombres estandarizados para código (`moodle_html`) y datos (`moodle_data`).

---

## 📁 Estructura del Repositorio

Para que Coolify construya la imagen sin incidencias, el repositorio debe contener únicamente estos dos archivos en la raíz:

```text
├── Dockerfile
├── docker-compose.yml
└── README.md
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
6. En el formulario de configuración inicial:
   * **Branch:** Selecciona `main` (o tu rama principal).
   * **Build Pack:** Selecciona **`Docker Compose`** *(Importante: no usar Nixpacks ni Railpack)*.
   * **Base Directory:** Déjalo en `/`.
7. Haz clic en **Continue**.

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
   * El VPS descargará la imagen base `php:8.3-apache`.
   * Se compilarán las extensiones nativas de PHP y se instalará Composer.
   * Se descargará Moodle 5.2 y se resolverán las dependencias del core.
   * Se crearán y montarán los volúmenes `moodle_html` y `moodle_data`.
3. **Verificación:** Cuando el proceso finalice, el indicador de estado cambiará a **verde (`Running`)**.

---

### Paso 5: Finalizar la Instalación Web

Abre en tu navegador la URL asignada:
```text
https://moodle.tudominio.com
```

1. **Selección de rutas:**
   * La dirección web (`wwwroot`) será detectada automáticamente.
   * El directorio de datos (`dataroot`) debe ser: `/var/www/moodledata`.
2. **Conexión a la base de datos:**
   * **Tipo:** MariaDB (o MySQL según corresponda).
   * **Host de la base de datos:** IP o hostname del servidor de BD.
   * **Nombre de la base de datos:** `moodle_db`.
   * **Usuario de la base de datos:** `moodle_user`.
   * **Contraseña:** `TuPasswordSeguro123`.
   * **Puerto:** `3306`.
   * **Socket Unix:** *Dejar completamente en blanco*.
3. **Comprobaciones del entorno:**
   * Todas las extensiones y directivas (`zend.exception_ignore_args`, Composer, Router) aparecerán en verde ("OK").
4. Haz clic en **Continuar** para ejecutar la creación de tablas y finalizar la cuenta administradora.

---

### ⚠️ Parámetro Crítico en `config.php` (Proxy SSL)

Al finalizar la instalación o si configuras `config.php` de forma manual, asegúrate de que el archivo contenga:

```php
$CFG->wwwroot  = 'https://moodle.tudominio.com';
$CFG->sslproxy = true;
```

> **IMPORTANTE:** **NO** agregues `$CFG->reverseproxy = true;`. Coolify utiliza Traefik para gestionar el certificado SSL e interactúa con el contenedor mediante HTTP interno; el parámetro `reverseproxy` causará un error de bloqueo en pantalla (`Reverse proxy enabled so the server cannot be accessed directly`). Con `$CFG->sslproxy = true;` los estilos CSS, scripts y peticiones HTTPS funcionarán con normalidad.
