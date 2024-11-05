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


resource "docker_image" "php_custom" {
  name         = "php_custom:fpm"
  build {
    path = "${path.module}"
    dockerfile = "Dockerfile.php"
  }
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
        index test_bdd.php index.html index.htm;
    }

    location ~ \.php$ {
        root /app;
        fastcgi_pass script:9000;
        fastcgi_index test_bdd.php;
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
  image = docker_image.php_custom.image_id

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
$pdo = new PDO('mysql:host=data;dbname=testdb', 'root', 'password');


$pdo->exec("CREATE TABLE IF NOT EXISTS visits (id INT AUTO_INCREMENT PRIMARY KEY, visit_count INT)");


$stmt = $pdo->query("SELECT visit_count FROM visits WHERE id=1");
$visit = $stmt->fetchColumn();


if ($visit) {
    $pdo->exec("UPDATE visits SET visit_count = visit_count + 1 WHERE id=1");
} else {
    $pdo->exec("INSERT INTO visits (visit_count) VALUES (1)");
    $visit = 1;
}

echo "Nombre de visites : " . $visit;
?>
EOF
    file = "/app/test_bdd.php"
  }
}


resource "docker_container" "data_container" {
  name  = "data"
  image = "mariadb:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  env = [
    "MYSQL_ROOT_PASSWORD=password",
    "MYSQL_DATABASE=testdb"
  ]


  volumes {
    container_path = "/var/lib/mysql"
    volume_name    = docker_volume.app_volume.name
  }
}
