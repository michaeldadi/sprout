#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <environment> <validate|plan|apply> [terraform options]" >&2
  exit 2
fi

environment="$1"
operation="$2"
shift 2

if [[ ! "$environment" =~ ^[a-z][a-z0-9_-]*$ ]]; then
  echo "Invalid environment name: $environment" >&2
  exit 2
fi

config="$root/environments/$environment.tfvars"
if [[ ! -f "$config" ]]; then
  echo "No configuration for environment: $environment" >&2
  exit 2
fi

case "$operation" in
  validate)
    terraform -chdir="$root" fmt -check -recursive
    terraform -chdir="$root" init -backend=false -input=false
    terraform -chdir="$root" validate
    ;;
  plan|apply)
    if [[ ! -f "$root/backend.hcl" ]]; then
      echo "Create untracked backend.hcl from backend.hcl.example first." >&2
      exit 2
    fi
    if [[ -z "${APPWRITE_API_KEY:-}" || -z "${APPWRITE_ORGANIZATION_API_KEY:-}" ]]; then
      echo "Set APPWRITE_API_KEY and APPWRITE_ORGANIZATION_API_KEY securely." >&2
      exit 2
    fi
    export TF_WORKSPACE="$environment"
    terraform -chdir="$root" init -input=false -reconfigure -backend-config="$root/backend.hcl"
    if [[ "$(terraform -chdir="$root" workspace show)" != "$environment" ]]; then
      echo "Terraform selected the wrong workspace." >&2
      exit 2
    fi
    if [[ "$operation" == "plan" ]]; then
      umask 077
      mkdir -p "$root/.plans"
      plan_file="$root/.plans/$environment.tfplan"
      terraform -chdir="$root" plan -input=false -var-file="$config" -out="$plan_file" "$@"
      shasum -a 256 "$plan_file"
      echo "Review the plan above, then run: $0 $environment apply"
    else
      plan_file="$root/.plans/$environment.tfplan"
      if [[ ! -f "$plan_file" ]]; then
        echo "No saved plan for $environment. Run $0 $environment plan first." >&2
        exit 2
      fi
      if [[ $# -ne 0 ]]; then
        echo "Apply accepts no extra options; it uses the saved environment plan." >&2
        exit 2
      fi
      shasum -a 256 "$plan_file"
      terraform -chdir="$root" apply -input=false "$plan_file"
    fi
    ;;
  *)
    echo "Unsupported operation: $operation" >&2
    exit 2
    ;;
esac
