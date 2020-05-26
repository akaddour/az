provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "cs" {
  name     = "${var.prefix}-resources"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "cs" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.cs.location
  resource_group_name = azurerm_resource_group.cs.name
}

resource "azurerm_subnet" "endpoint" {
  name                 = "endpoint"
  resource_group_name  = azurerm_resource_group.cs.name
  virtual_network_name = azurerm_virtual_network.cs.name
  address_prefixes       = ["10.0.1.0/24"]

  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_postgresql_server" "cs" {
  name                = "${var.prefix}-postgresql"
  location            = azurerm_resource_group.cs.location
  resource_group_name = azurerm_resource_group.cs.name

  administrator_login          = "csuser"
  administrator_login_password = "MyAwes1OmePwd1"
  auto_grow_enabled            = true
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  sku_name                     = "GP_Gen5_2"
  storage_mb                   = 51200
  version                      = "11"
  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}

resource "azurerm_private_endpoint" "cs" {
  name                 = "${var.prefix}-pe"
  location             = azurerm_resource_group.cs.location
  resource_group_name  = azurerm_resource_group.cs.name
  subnet_id            = azurerm_subnet.endpoint.id

  private_service_connection {
    name                           = "tfex-postgresql-connection"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_postgresql_server.cs.id
    subresource_names              = ["postgresqlServer"]
  }
}
