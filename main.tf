terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">2.91.0"
    }
  }
}


provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {

  name     = "DevRG"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "hub-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "main"
  address_prefixes     = ["10.0.0.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet2" {
  name                 = "GatewaySubnet"
  address_prefixes     = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}



resource "azurerm_network_security_group" "NSG" {
  name                = "Main-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "Rule1" {
  name                        = "InboundRule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.NSG.name

}

resource "azurerm_subnet_network_security_group_association" "associationOnMain" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}



resource "azurerm_network_interface" "nic1" {
  name                = "vm1-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    
  }
}


resource "azurerm_virtual_machine" "VM1" {
  name                  = "DevVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic1.id]
  vm_size               = "Standard_B1s"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"

  }

  storage_os_disk {
    name              = "osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "devvm"
    admin_username = "ando"
    admin_password = "SecurePa$5word123"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }


}


resource "azurerm_virtual_network" "spoke1" {

  name                = "spoke-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  address_space = ["10.1.0.0/16"]

}

resource "azurerm_subnet" "spokesubnet" {
  name = "spoke-main"

  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "spoke1association" {
  subnet_id                 = azurerm_subnet.spokesubnet.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}

resource "azurerm_network_interface" "nic2" {
  name                = "vm2-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.spokesubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "VM2" {
  name                  = "DevVM-spoke"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic2.id]
  vm_size               = "Standard_B1s"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"

  }

  storage_os_disk {
    name              = "osdisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "devvm-spoke"
    admin_username = "ando"
    admin_password = "SecurePa$5word123"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }


}

resource "azurerm_virtual_network_peering" "hubside" {
  name                         = "hub-to-spoke"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spokeside" {
  name                         = "spoke-to-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}


resource "azurerm_public_ip" "pip" {
  name                = "vpnpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "vpn"{ 
  name = "vpn-gw"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp = false
  sku = "VpnGw1"

  ip_configuration {
    name = "vpn-ipconfig"
    public_ip_address_id = azurerm_public_ip.pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.subnet2.id
  }

  vpn_client_configuration {
    address_space = ["198.10.0.0/24"]

    root_certificate {
      name = "RootCert"

      public_cert_data = <<EOF
      MIIC5zCCAc+gAwIBAgIQEYQmy8IQIZRJ1cslIINOgzANBgkqhkiG9w0BAQsFADAW
MRQwEgYDVQQDDAtQMlNSb290Q2VydDAeFw0yMzEwMjExOTUwNThaFw0yNTEwMjEy
MDAwNTVaMBYxFDASBgNVBAMMC1AyU1Jvb3RDZXJ0MIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEAobhV3Qv4T1GGk+g27YBJSrr91jM4TTeP0tJRtGVe3VyX
yuXXuwJEi79j6dVNF1ttHrD1xWDugv42fL8YU5TR99S64vqj7sdixmzXsgWDt/0g
1d4AN5hbcD+9BZ2GR8eOZ4L6BhBT2m/cABzcdtBrCmv8VDOlOGeaGx0oQrU/swPd
95dDBW8T2xUCKOa2/BJCpL7Orza30sTp2TjED7Dx1uhvAv66Z35aPpz8ZjwC0RnE
rTw+KsY5geVXPqQJWWuPA2HWOpXZUso5YEUsQRbzfwrUEFOqahEIEH9l6cwwir2z
bAclsBkr23sMSCn1vsMpwKROoAnsHL1C0TzFNsJgsQIDAQABozEwLzAOBgNVHQ8B
Af8EBAMCAgQwHQYDVR0OBBYEFPKUlkng0cCMye/v4oJpnUtyF9MxMA0GCSqGSIb3
DQEBCwUAA4IBAQBemp4lvIdtH0jbP2kqjC6RIgyudxo5bNWB0bT7bcERvhvEPTKe
empz85IAsShUYDIYd0KKWq9KtGPfdCezCHwRWkxTQ5AnUHPaR/5QIaCjQLQj7vEF
kEvR2LGt0SKGwhgLPe0u9w+msdJlIrM1ZVs660RciwnrW4ijgM46V+229gkCgn/x
NXC2OEDyvArSEp66EOloNZYnjBRo3hADMyJ/dFkRZE8K+/gPNNx8YbGT2Nt65/Ug
2WsZYsarVQp5+/NZ0t8iAd1af+QFLKVfpLZX4Fol5oLuQVGsXu9KKyiW0/Xkny4/
o/YA7LjKSTnRNGg/4JXN1tv4rspQJJaMJyRm
EOF

    }


  }
}

