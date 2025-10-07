# ./vault/config.hcl
ui            = true
disable_mlock = true
storage "file" { path = "/vault/data" }

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = 1
}

api_addr     = "http://vault:8200"
cluster_addr = "http://vault:8201"
