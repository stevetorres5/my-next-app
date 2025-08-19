# Terraform Bootstrap for Essaypop Infrastructure

This directory contains the **one-time, account-level bootstrap** Terraform configuration for the Essaypop AWS environment.  
It sets up global resources required for all environments, such as the S3 backend for Terraform state, IAM roles and policies for CI/CD, and the GitHub Actions OIDC provider.

---

## ⚠️ Important Notes

- **Run this bootstrap only ONCE per AWS account.**  
  These resources are global and should not be recreated for each environment.
  Then, continue to deploy through GH Actions.

---

## What Does This Bootstrap Do?

- **Creates the S3 bucket** for storing Terraform state files.
- **Creates the IAM OIDC provider** for GitHub Actions (only once per AWS account).
- **Creates IAM roles and policies** for CI/CD pipelines, including:
  - Attaching AWS managed policies (e.g., `AdministratorAccess-Amplify`)
  - Inline policies for SSM, KMS, and S3 access
- **Outputs the ARN** of the assumable role for use in GitHub Actions workflows.

---

## Usage

### 1. Bootstrap the OIDC Provider (One Time Only)

If the OIDC provider for GitHub Actions (`https://token.actions.githubusercontent.com`) does **not** exist in your AWS account, create it:

```sh
cd terraform/bootstrap/oidc-provider
terraform init
terraform plan
terraform apply
```

If it already exists, skip this step or use a [data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) to reference it.

---

### 2. Run the Bootstrap

```sh
cd terraform/bootstrap
terraform init
terraform workspace new <ENV>      # Only if this workspace does not exist
terraform workspace select <ENV>
terraform plan
terraform apply
```

- Replace `<ENV>` with your environment name (e.g., `sandbox`, `dev`, `prod`).
- This will create the S3 state bucket, IAM roles, and policies.

---

### 3. Copy the Assumable Role ARN

After a successful apply, **copy the ARN** for the IAM role that GitHub Actions will assume.  
You can find it in the Terraform output or in the AWS Console:

```
arn:aws:iam::<account number>:role/<role name>
```

---

### 4. Configure GitHub Actions

- Store the role ARN in a configuration file (e.g., `roles.json`) or as a GitHub Actions secret.
- In your workflow, dynamically select the correct role ARN based on the environment.
- Use the [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials) action with `role-to-assume`.

Example snippet for reading from `roles.json`:

```yaml
- name: Read role ARN from JSON
  id: readrole
  run: |
    ROLE_TO_ASSUME=$(jq -r ".${{ github.event.inputs.env }}" roles.json)
    if [ -z "$ROLE_TO_ASSUME" ] || [ "$ROLE_TO_ASSUME" = "null" ]; then
      echo "ERROR: No role ARN found for environment '${{ github.event.inputs.env }}'."
      exit 1
    fi
    echo "ROLE_TO_ASSUME=$ROLE_TO_ASSUME" >> $GITHUB_OUTPUT

- name: Configure AWS Credentials (OIDC)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ steps.readrole.outputs.ROLE_TO_ASSUME }}
    aws-region: us-west-2
```

---

- **.terraform.lock.hcl**: Commit this file to version control for provider version consistency.

---

## Troubleshooting

- **OIDC Provider Already Exists**:  
  If you see `EntityAlreadyExists` for the OIDC provider, it means it was already created. Use a data source to reference it instead of creating it again.
- **S3 State File Conflicts**:  
  Ensure each environment uses a unique state file key or bucket.
- **Missing Role ARN in Workflow**:  
  Make sure your `roles.json` or secrets are up to date and accessible in your workflow.

---

## Additional Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions OIDC Integration](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Terraform State Backends](https://www.terraform.io/language/state/backends/s3)

---
