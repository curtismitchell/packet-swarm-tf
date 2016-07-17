provider "packet" {
  /*read from environment variable */
}

resource "packet_project" "swarm_project" {
  name = "Swarm PaaS"
}

output "managers" {
  value = "${join(", ", packet_device.auto_managers.*.network.0.address)}"
}

output "nodes" {
  value = "${join(", ", packet_device.auto_nodes.*.network.0.address)}"
}

variable "grep_cmd" {
  default = "docker info | grep sha256: | awk '{ print $2 }'"
}

variable "swarm_secret" {
  default = "dd747erdepc2sgf9bm8s4crxh" /* pull this from a safe place */
}

resource "packet_device" "auto_managers" {
  hostname = "${concat("auto-manager0", count.index + 1)}"
  plan = "baremetal_0"
  facility = "ewr1"
  operating_system = "ubuntu_14_04_image"
  billing_cycle = "hourly"
  project_id = "${packet_project.swarm_project.id}"
  count = 1

  connection {
    user = "root"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://test.docker.com/ | sh"
    ]
  }

  provisioner "local-exec" {
    command = "ssh -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' root@${self.network.0.address} 'docker swarm init --listen-addr ${self.network.2.address}:2377 --secret ${var.swarm_secret} --auto-accept worker,manager'"
  }

  provisioner "local-exec" {
    command = "ssh -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' root@${self.network.0.address} ${var.grep_cmd} > ./join-script.sh"
  }
}

resource "packet_device" "auto_nodes" {
  depends_on = ["packet_device.auto_managers"]
  hostname = "${concat("auto-node0", count.index + 1)}"
  plan = "baremetal_0"
  facility = "ewr1"
  operating_system = "ubuntu_14_04_image"
  billing_cycle = "hourly"
  project_id = "${packet_project.swarm_project.id}"
  count = 2

  connection {
    user = "root"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -fsSL https://test.docker.com/ | sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "docker swarm join --secret ${var.swarm_secret} --listen-addr ${self.network.2.address}:2377 --ca-hash ${trimspace(file("./join-script.sh"))} ${packet_device.auto_managers.0.network.2.address}:2377"
    ]
  }
}
