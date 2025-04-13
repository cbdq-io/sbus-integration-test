locals {
  certs_abs_path = abspath("${path.module}/../../../../certs")
  cert_files     = tolist(fileset("${path.module}/../../../../certs", "*"))

  location_abbreviation = {
    "UK South" = "uks",
    "UK West"  = "ukw"
  }

  resource_name_prefix = "sbox-${local.location_abbreviation[var.location]}"

  sbns_name = "${local.resource_name_prefix}-sbns-${random_integer.numeric_suffix.result}"
}
