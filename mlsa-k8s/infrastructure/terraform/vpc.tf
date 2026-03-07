# VPC Network and Subnet for GKE

resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.main.id
  region        = var.region

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# Firewall: Allow internal communication
resource "google_compute_firewall" "internal" {
  name      = "${var.network_name}-allow-internal"
  network   = google_compute_network.main.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = [var.subnet_cidr]
}

# Firewall: Allow SSH from admin (for debugging)
resource "google_compute_firewall" "ssh" {
  name      = "${var.network_name}-allow-ssh"
  network   = google_compute_network.main.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.admin_cidr]
}

# Firewall: Allow HTTPS (kubectl API)
resource "google_compute_firewall" "api" {
  name      = "${var.network_name}-allow-api"
  network   = google_compute_network.main.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [var.admin_cidr]
}

# Firewall: Allow SSH from bastion (optional)
resource "google_compute_firewall" "allow_ssh" {
  name    = "mlsa-k8s-allow-ssh"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]  # Restrict this in production
  target_tags   = ["mlsa-k8s-ssh"]
}

# Firewall: Allow API server access (internal)
resource "google_compute_firewall" "allow_api" {
  name    = "mlsa-k8s-allow-api"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["10.0.0.0/8"]
}

# Firewall: Allow health checks
resource "google_compute_firewall" "allow_health_check" {
  name    = "mlsa-k8s-allow-health-check"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

# Cloud NAT for egress traffic
resource "google_compute_router" "router" {
  name    = "mlsa-k8s-router"
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "mlsa-k8s-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
