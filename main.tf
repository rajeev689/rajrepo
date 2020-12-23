provider "azurerm" {
features{}
}

resource "azurerm_resource_group" "web_server_rg" {
name = var.web_server_rg
location = var.web_server_location
}

resource "azurerm_virtual_network" "web_server_vnt" {
name = "${var.resource_prefix}-vnet"
location = var.web_server_location
address_space = [var.web_server_address_space]
resource_group_name = azurerm_resource_group.web_server_rg.name
}

resource "azurerm_subnet" "web_server_sbnet" {
name = "${var.resource_prefix}-subnet"
resource_group_name = azurerm_resource_group.web_server_rg.name
virtual_network_name = azurerm_virtual_network.web_server_vnt.name 
address_prefixes = [var.web_server_address_prefix]
}

resource "azurerm_network_interface" "web_server_nic" {
name = "${var.web_server_name}-${format("%02d",count.index)}-nic"
count = var.web_server_count
location = var.web_server_location
resource_group_name = azurerm_resource_group.web_server_rg.name

ip_configuration {
name = "${var.web_server_name}-ip"
subnet_id = azurerm_subnet.web_server_sbnet.id
private_ip_address_allocation = "dynamic"
public_ip_address_id = count.index==0 ? azurerm_public_ip.web_server_public_ip.id : null
}
}

#add public ip
resource "azurerm_public_ip" "web_server_public_ip" {
name = "${var.resource_prefix}-public-ip"
location = var.web_server_location
resource_group_name = azurerm_resource_group.web_server_rg.name
allocation_method = var.environment=="production"?"Static":"Dynamic"
}

#create network security group
resource "azurerm_network_security_group" "web_server_nsg" {
name = "${var.resource_prefix}-nsg"
resource_group_name = azurerm_resource_group.web_server_rg.name
location = var.web_server_location
}

#adding nsg rule
resource "azurerm_network_security_rule" "web_server_nsg_rule_rdp" {
name = "RDP Inbound"
priority = 100
direction = "Inbound"
access = "Allow"
protocol = "TCP"
source_port_range = "*"
destination_port_range = "3389"
source_address_prefix = "*"
destination_address_prefix = "*"
resource_group_name = azurerm_resource_group.web_server_rg.name
network_security_group_name = azurerm_network_security_group.web_server_nsg.name
}

#associating nsg with nic
resource "azurerm_subnet_network_security_group_association" "web_server_sag" {
network_security_group_id = azurerm_network_security_group.web_server_nsg.id
subnet_id = azurerm_subnet.web_server_sbnet.id
}

#Creating a windows virtual machine
resource "azurerm_windows_virtual_machine" "webserver" {
    name = "${var.web_server_name}-${format("%02d",count.index)}"
    location = var.web_server_location
    count = var.web_server_count
    resource_group_name = azurerm_resource_group.web_server_rg.name
    network_interface_ids = [azurerm_network_interface.web_server_nic[count.index].id]
    size = "Standard_B1s"
    availability_set_id = azurerm_availability_set.web_server_availability_set.id
    admin_username = "rajeev689"
    admin_password = "R@jeev689999"

    os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer = "WindowsServer"
        sku = "2016-Datacenter"
        version = "latest"
    }
}

#creating availability set
resource "azurerm_availability_set" "web_server_availability_set" {
name = "${var.resource_prefix}-availability-set"
resource_group_name = azurerm_resource_group.web_server_rg.name
location = var.web_server_location  
managed = true
platform_fault_domain_count = 2
}