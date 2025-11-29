#!/bin/bash
# Usage: ./terraform.sh plan|apply

ENV=$(terraform workspace show)
if [ "$ENV" = "default" ]; then
  ENV="dev"
fi

echo "Current workspace: $ENV"
VAR_FILE="envs/$ENV/terraform.tfvars"

# Ensure Azure subscription is available for the azurerm provider.
# Terraform's azurerm provider will try to infer subscription from environment
# or the Azure CLI. If `ARM_SUBSCRIPTION_ID` isn't set, try to detect it
# from `az account show`. If detection fails, instruct the user to run
# `az login` or set the `ARM_SUBSCRIPTION_ID` env var.
if [ -z "$ARM_SUBSCRIPTION_ID" ]; then
  if command -v az >/dev/null 2>&1; then
    DETECTED_SUBSCRIPTION=$(az account show --query id -o tsv 2>/dev/null || true)
    if [ -n "$DETECTED_SUBSCRIPTION" ]; then
      export ARM_SUBSCRIPTION_ID="$DETECTED_SUBSCRIPTION"
      echo "Detected Azure subscription." 
    else
      echo "Error: ARM_SUBSCRIPTION_ID not set and no logged-in Azure account found." >&2
      echo "Run 'az login' to authenticate, or set the ARM_SUBSCRIPTION_ID environment variable." >&2
      exit 1
    fi
  else
    echo "Error: ARM_SUBSCRIPTION_ID not set and Azure CLI ('az') not found." >&2
    echo "Install Azure CLI or set ARM_SUBSCRIPTION_ID environment variable." >&2
    exit 1
  fi
fi

CMD="$1"
case "$CMD" in
  plan|apply|destroy|import|refresh)
    terraform "$@" -var-file="$VAR_FILE"
    ;;
  *)
    terraform "$@"
    ;;
esac
