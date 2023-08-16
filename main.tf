locals {
  name  = var.name
  owner = var.owner
  # vpc
  vpc_name = var.vpc_name
  vpc_cidr = var.vpc_cidr # this should be "" if the vpc already exists
  # subnet
  subnet_name = var.subnet_name
  subnet_cidr = var.subnet_cidr # this should be "" if the subnet already exists
  # security group
  security_group_name = var.security_group_name
  security_group_type = var.security_group_type # this should be "" if the security group already exists
  security_group_ip   = var.security_group_ip   # this can be "", but it will cause the module to attempt to look up the current public ip
  # ssh access
  username        = var.ssh_username
  ssh_key_name    = var.ssh_key_name
  ssh_key_content = var.ssh_key_content
  # server
  server_name = local.name      # this module shouldn't override the server with server_id
  server_type = var.server_type # this should be "" if the server already exists
  # image
  image_type = var.image_type # this module shouldn't override the image with image_id
  # rke2
  rke2_version    = var.rke2_version    # even when supplying your own files, please provide the release version to install
  local_file_path = var.local_file_path # this should be "" if you want to download from github
  join_token      = var.join_token      # this should be set, even if you are only deploying one server
  role            = var.role            # this should be "server" or "agent", defaults to "server"
  # initial_url should be null on the first server, and the url of the first server on all other servers
  initial_url = var.initial_server_url
}

module "aws_access" {
  source              = "rancher/access/aws"
  version             = "v0.0.2"
  owner               = local.owner
  vpc_name            = local.vpc_name
  vpc_cidr            = local.vpc_cidr
  subnet_name         = local.subnet_name
  subnet_cidr         = local.subnet_cidr
  security_group_name = local.security_group_name
  security_group_type = local.security_group_type
  security_group_ip   = local.security_group_ip
  ssh_key_name        = local.ssh_key_name
  public_ssh_key      = local.ssh_key_content
}

module "aws_server" {
  depends_on = [
    module.aws_access
  ]
  source                     = "rancher/server/aws"
  version                    = "v0.0.3"
  server_name                = local.server_name
  server_owner               = local.owner
  server_type                = local.server_type
  image                      = local.image_type
  server_user                = local.username
  server_ssh_key             = module.aws_access.ssh_key.public_key
  server_security_group_name = module.aws_access.security_group.tags.Name
  server_subnet_name         = module.aws_access.subnet.tags.Name
}

module "node_config" {
  depends_on = [
    module.aws_access,
    module.aws_server,
  ]
  source  = "rancher/rke2-config/local"
  version = "v0.0.3"
  token   = local.join_token
  server  = local.initial_url
}

module "install" {
  depends_on = [
    module.aws_access,
    module.aws_server,
    module.node_config,
  ]
  source            = "rancher/rke2-install/github"
  version           = "v0.0.4"
  release           = local.rke2_version
  local_file_path   = local.local_file_path
  server_identifier = module.aws_server.id
  ssh_ip            = module.aws_server.public_ip
  ssh_user          = local.username
  rke2_config       = module.node_config.yaml_config
  role              = local.role
}
