import {
  to = module.cluster.google_compute_address.nat_ip
  id = "projects/solaria-authenticator/regions/us-central1/addresses/solaria-nat-ip"
}

import {
  to = module.cluster.google_compute_router.router
  id = "projects/solaria-authenticator/regions/us-central1/routers/solaria-router"
}

import {
  to = module.cluster.google_compute_router_nat.nat
  id = "projects/solaria-authenticator/regions/us-central1/routers/solaria-router/solaria-nat"
}
