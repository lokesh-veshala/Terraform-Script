# Define variables
variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "instance_type" {
  description = "Type of the instance"
  type        = string
}

variable "volume_size" {
  description = "Size of the volume (in GB)"
  type        = number
}

# Define provider block
provider "aws" {
  region = "us-west-2"
}

provider "vsphere" {
  user           = var.vmware_username
  password       = var.vmware_password
  vsphere_server = var.vmware_server
}

# Determine the provider dynamically based on environment variables or command-line arguments
provider "dynamic" {
  version = "2.0.0"

  # If "TF_VAR_provider" environment variable is set, use it as the provider name
  providers {
    aws = aws
    vsphere = vsphere
  }

  default_provider = aws
}

# Define resources
resource "dynamic" "example" {
  for_each = var.provider == "aws" ? { aws = true } : { vsphere = true }

  content {
    aws_instance.example = {
      ami           = "ami-12345678"
      instance_type = var.instance_type
      tags = {
        Name = var.instance_name
      }
    }

    vsphere_virtual_machine.example = {
      name          = var.instance_name
      resource_pool = "my-cluster/resource-pool"
      datastore     = "my-datastore"
      num_cpus      = 2
      memory        = 2048
    }
  }
}

# Attach volume to the instance
resource "aws_volume_attachment" "example" {
  for_each     = var.provider == "aws" ? dynamic.example : {}
  device_name = "/dev/sdf"
  instance_id = each.value.aws_instance.example.id
  volume_id   = aws_ebs_volume.example.id
}

resource "vsphere_virtual_machine_disk" "example" {
  for_each       = var.provider == "vsphere" ? dynamic.example : {}
  label          = "disk0"
  size           = var.volume_size
  datastore      = "my-datastore"
  vm_id          = each.value.vsphere_virtual_machine.example.id
  controller_type = "scsi"
  unit_number    = 0
}

# Define outputs
output "public_ip" {
  value = dynamic.example[*].aws_instance.example[*].public_ip
}

output "private_ip" {
  value = dynamic.example[*].aws_instance.example[*].private_ip
}
