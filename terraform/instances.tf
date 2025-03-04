variable "hostname_blocks" {}
variable "name_block" {}
variable "images_blocks" {}
variable "cores_blocks" {}
variable "memory_blocks" {}
variable "core_fraction_blocks" {}

variable "count_vm" {}

#--------------- vns -----------------
resource "yandex_compute_instance" "vm" {
  count = var.count_vm

  name = var.name_block[count.index]
  hostname = var.hostname_blocks[count.index]

  allow_stopping_for_update = true
  platform_id = "standard-v1"
  #zone = local.zone

  resources {
    core_fraction = var.core_fraction_blocks[count.index]
    cores = var.cores_blocks[count.index]
    memory = var.memory_blocks[count.index]
  }

  boot_disk {
    initialize_params {
      image_id = var.images_blocks[count.index]
      size = 16
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat = true
  }

  scheduling_policy {
    preemptible = true
  }

  metadata = {
    user-data = file("./meta.yml")
  }

  #------------ creating dirs------------
  provisioner "remote-exec" {
    inline = [
      "cd ~",
      "mkdir -pv configs",
      "mkdir -pv docker_volumes",
      "mkdir -pv docker_volumes/elasticsearch",
      "mkdir -pv configs",
      "mkdir -pv configs/elasticsearch",
      "mkdir -pv configs/filebeat",
      "mkdir -pv configs/kibana",
      "mkdir -pv configs/logstash",
      "mkdir -pv configs/logstash/pipelines"
    ]
  }

  #--------- copying files --------
  provisioner "file" {
    source      = "../docker-compose.yaml"
    destination = "/home/dmil/docker-compose.yaml"
  }

  provisioner "file" {
    source      = "../configs/elasticsearch/config.yml"
    destination = "/home/dmil/configs/elasticsearch/config.yml"
  }

  provisioner "file" {
    source      = "../configs/filebeat/config.yml"
    destination = "/home/dmil/configs/filebeat/config.yml"
  }

  provisioner "file" {
    source      = "../configs/kibana/config.yml"
    destination = "/home/dmil/configs/kibana/config.yml"
  }

  provisioner "file" {
    source      = "../configs/logstash/config.yml"
    destination = "/home/dmil/configs/logstash/config.yml"
  }

  provisioner "file" {
    source      = "../configs/logstash/pipelines/service_stamped_json_logs.conf"
    destination = "/home/dmil/configs/logstash/pipelines/service_stamped_json_logs.conf"
  }

  provisioner "file" {
    source      = "../configs/logstash/pipelines.yml"
    destination = "/home/dmil/configs/logstash/pipelines.yml"
  }

  #----------------------------------
  provisioner "remote-exec" {
    inline = [
    # Обновление пакетов
    "sudo apt-get update",

    # Установка зависимостей для Docker
    "sudo apt-get install -y ca-certificates curl gnupg",
    "sudo install -m 0755 -d /etc/apt/keyrings",
    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
    "sudo chmod a+r /etc/apt/keyrings/docker.gpg",

    # Добавление Docker-репозитория
    "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",

    # Установка Docker
    "sudo apt-get update",
    "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || echo 'Failed to install Docker'",

    # Проверка установки Docker
    "docker --version || echo 'Docker is not installed'",

    # Установка Nginx
    "sudo apt update",
    "sudo apt install -y nginx",
    "sudo chmod 777 /var/log/nginx/access.log",

    # Установка Redis
    "sudo apt install -y redis",
    "sudo curl localhost",
    "sudo systemctl restart redis",
    "sudo chmod o+rx -R /var/log/redis",

    # Проверка установки Docker Compose
    "docker compose version || echo 'Docker Compose is not installed'",

    # Запуск Docker Compose
    "sudo docker compose up -d"
  ]
}
  connection {
    type        = "ssh"
    user        = "dmil"
    private_key = file("~/.ssh/id_ed25519")
    host        = self.network_interface[0].nat_ip_address
  }
}
