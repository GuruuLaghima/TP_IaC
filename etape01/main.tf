terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.25.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}


resource "docker_network" "app_network" {
  name = "app_network"
}


resource "docker_volume" "app_volume" {
  name = "app_volume"
}


resource "docker_container" "http_container" {
  name  = "http"
  image = "nginx:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  volumes {
    container_path = "/app"
    volume_name    = docker_volume.app_volume.name
  }

  ports {
    internal = 80
    external = 8080
  }


  upload {
    content = <<EOF
server {
    listen 80;
    server_name localhost;

    location / {
        root /app;
        index index.php index.html index.htm;
    }

    location ~ \.php$ {
        root /app;
        fastcgi_pass script:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
    file = "/etc/nginx/conf.d/default.conf"
  }
}


resource "docker_container" "script_container" {
  name  = "script"
  image = "php:fpm"

  networks_advanced {
    name = docker_network.app_network.name
  }

  volumes {
    container_path = "/app"
    volume_name    = docker_volume.app_volume.name
  }


  upload {
    content = <<EOF
<?php
phpinfo();
?>
EOF
    file = "/app/index.php"
  }
}
