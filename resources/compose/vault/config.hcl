# ./vault/config.hcl
ui            = true
disable_mlock = true
storage "file" { path = "/vault/data" }

listener "tcp" {
  address                   = "0.0.0.0:8200"
  tls_disable               = false
  tls_cert_file             = "/vault/tls/fullchain.pem"   
  tls_key_file              = "/vault/tls/privkey.pem"
  tls_disable_client_certs  = true                         
}

api_addr     = "https://vault.sttlab.local:8200"