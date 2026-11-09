output "project_id" {
  value = appwrite_project.this.id
}

output "database_id" {
  value = appwrite_tablesdb.primary.id
}

output "site_id" {
  value = appwrite_site.landing.id
}
