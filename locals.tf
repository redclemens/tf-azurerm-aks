locals {
  # Abstract if auto_scaler_profile_scale_down_delay_after_delete is not set or null we should use the scan_interval.
  auto_scaler_profile_scale_down_delay_after_delete = var.auto_scaler_profile_scale_down_delay_after_delete == null ? var.auto_scaler_profile_scan_interval : var.auto_scaler_profile_scale_down_delay_after_delete
  # automatic upgrades are either:
  # - null
  # - patch, but then neither the kubernetes_version nor orchestrator_version must specify a patch number, where orchestrator_version may be also null
  # - rapid/stable/node-image, but then the kubernetes_version and the orchestrator_version must be null
  automatic_channel_upgrade_check = var.automatic_channel_upgrade == null ? true : (
    (contains(["patch"], var.automatic_channel_upgrade) && can(regex("^[0-9]{1,}\\.[0-9]{1,}$", var.kubernetes_version)) && (can(regex("^[0-9]{1,}\\.[0-9]{1,}$", var.orchestrator_version)) || var.orchestrator_version == null)) ||
    (contains(["rapid", "stable", "node-image"], var.automatic_channel_upgrade) && var.kubernetes_version == null && var.orchestrator_version == null)
  )
  cluster_name = try(coalesce(var.cluster_name, trim("${var.prefix}-aks", "-")), "aks")
  # Abstract the decision whether to create an Analytics Workspace or not.
  create_analytics_solution        = var.log_analytics_workspace_enabled && var.log_analytics_solution == null
  create_analytics_workspace       = var.log_analytics_workspace_enabled && var.log_analytics_workspace == null
  default_nodepool_subnet_segments = try(split("/", try(var.vnet_subnet.id, null)), [])
  # Application Gateway ID: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/applicationGateways/myGateway1
  existing_application_gateway_for_ingress_id             = try(var.brown_field_application_gateway_for_ingress.id, null)
  existing_application_gateway_resource_group_for_ingress = var.brown_field_application_gateway_for_ingress == null ? null : local.existing_application_gateway_segments_for_ingress[4]
  existing_application_gateway_segments_for_ingress       = var.brown_field_application_gateway_for_ingress == null ? null : split("/", local.existing_application_gateway_for_ingress_id)
  existing_application_gateway_subnet_resource_group_name = try(local.existing_application_gateway_subnet_segments[4], null)
  # Subnet ID: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1/subnets/mysubnet1
  existing_application_gateway_subnet_segments                    = try(split("/", var.brown_field_application_gateway_for_ingress.subnet_id), [])
  existing_application_gateway_subnet_subscription_id_for_ingress = try(local.existing_application_gateway_subnet_segments[2], null)
  existing_application_gateway_subnet_vnet_name                   = try(local.existing_application_gateway_subnet_segments[8], null)
  existing_application_gateway_subscription_id_for_ingress        = try(local.existing_application_gateway_segments_for_ingress[2], null)
  ingress_application_gateway_enabled                             = local.use_brown_field_gw_for_ingress || local.use_green_field_gw_for_ingress
  # Abstract the decision whether to use an Analytics Workspace supplied via vars, provision one ourselves or leave it null.
  # This guarantees that local.log_analytics_workspace will contain a valid `id` and `name` IFF log_analytics_workspace_enabled
  # is set to `true`.
  log_analytics_workspace = var.log_analytics_workspace_enabled ? (
    # The Log Analytics Workspace should be enabled:
    var.log_analytics_workspace == null ? {
      # `log_analytics_workspace_enabled` is `true` but `log_analytics_workspace` was not supplied.
      # Create an `azurerm_log_analytics_workspace` resource and use that.
      id                  = local.azurerm_log_analytics_workspace_id
      name                = local.azurerm_log_analytics_workspace_name
      location            = local.azurerm_log_analytics_workspace_location
      resource_group_name = local.azurerm_log_analytics_workspace_resource_group_name
      } : {
      # `log_analytics_workspace` is supplied. Let's use that.
      id       = var.log_analytics_workspace.id
      name     = var.log_analytics_workspace.name
      location = var.log_analytics_workspace.location
      # `azurerm_log_analytics_workspace`'s id format: /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.OperationalInsights/workspaces/workspace1
      resource_group_name = split("/", var.log_analytics_workspace.id)[4]
    }
  ) : null # Finally, the Log Analytics Workspace should be disabled.
  node_pools_create_after_destroy                       = { for k, p in var.node_pools : k => p if p.create_before_destroy != true }
  node_pools_create_before_destroy                      = { for k, p in var.node_pools : k => p if p.create_before_destroy == true }
  private_dns_zone_name                                 = try(reverse(split("/", var.private_dns_zone_id))[0], null)
  query_datasource_for_log_analytics_workspace_location = var.log_analytics_workspace_enabled && (var.log_analytics_workspace != null ? var.log_analytics_workspace.location == null : false)
  subnet_ids                                            = [for _, s in local.subnets : s.id]
  subnets = merge({ for k, v in merge(
    [
      for key, pool in var.node_pools : {
        "${key}-vnet-subnet" : pool.vnet_subnet,
        "${key}-pod-subnet" : pool.pod_subnet,
      }
    ]...) : k => v if v != null }, var.vnet_subnet == null ? {} : {
    "vnet-subnet" : {
      id = var.vnet_subnet.id
    }
  })
  # subnet_ids                                            = for id in local.potential_subnet_ids : id if id != null
  use_brown_field_gw_for_ingress = var.brown_field_application_gateway_for_ingress != null
  use_green_field_gw_for_ingress = var.green_field_application_gateway_for_ingress != null
  valid_private_dns_zone_regexs = [
    "private\\.[a-z0-9]+\\.azmk8s\\.io",
    "privatelink\\.[a-z0-9]+\\.azmk8s\\.io",
    "[a-zA-Z0-9\\-]{1,32}\\.private\\.[a-z]+\\.azmk8s\\.io",
    "[a-zA-Z0-9\\-]{1,32}\\.privatelink\\.[a-z]+\\.azmk8s\\.io",
  ]
}
