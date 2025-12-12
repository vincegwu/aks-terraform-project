locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Create unique suffix for globally unique resources
  unique_suffix = var.resource_suffix != "" ? var.resource_suffix : substr(md5("${var.project_name}-${var.environment}"), 0, 6)

  tags = {
    environment = var.environment
    project     = var.project_name
    owner       = "devops"
  }
}
