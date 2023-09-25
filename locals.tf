locals {
  gateways = {
    for service in data.tfe_outputs.tfe.nonsensitive_values.services : service.name => {
      port = try(service.port, 80)
    } if service.type == "gateway"
  }
}
