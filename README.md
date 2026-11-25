# vault-krm-extensions

Kubernetes kinds for the Vault configuration that Terraform's
`hashicorp/vault` provider manages and Vault's operators do not. HashiCorp's Vault Secrets Operator syncs secrets into Kubernetes; it does not configure Vault. Red Hat CoP's vault-config-operator (96 CRDs) configures auth methods, secret engines, policies and identity; Bank-Vaults' operator runs Vault and applies a config file.

By the numbers: `hashicorp/vault` is the #13 Terraform provider by downloads
(1,004,945,885); version 5.13.0 has 217 resources. Operators
cover 82. This repository adds **117 kinds** standing in for
**122 more** of the 135 left. Each gap kind is listed below with its Terraform
equivalent; the rest, and why, are under "Not covered".

**Limits.** Actions Terraform models as resources (issuing or signing a certificate, logging in, rotating a key) are not desired state and are left out. A kind writes under a mount; create the mount first (vault-config-operator's SecretEngineMount or AuthEngineMount). Where a Terraform "backend" resource also enables the mount (`vault_kmip_secret_backend`, `vault_saml_auth_backend`, `vault_os_secret_backend`, `vault_alicloud_secret_backend`, `vault_gcpkms_secret_backend`, `vault_kv_secret_backend_v2`), its kind is the engine's or method's configuration only. Many kinds are for Vault Enterprise (Sentinel policies, control groups, managed keys, the legacy sys/mfa methods, Transform, KMIP, Key Management, secrets sync, SAML, SPIFFE, TPM, SCEP, EST/CMPv2, OS, PKI External CA, Agent Registry): they are fake-tested only, since the live tests run the open-source server.

**Readiness: 44 of 117 kinds also proven against the real API** (Vault 2.2.2,
open source, dev mode); the others are `fake`. Every kind passes create, update, drift repair and
delete against a fake built from the same descriptors (`TestEveryKindOnFake`).
The kinds in `hack/live/live.yaml` run the same steps against a real Vault
(`TestEveryKindLive`, built only with `-tags live`); `hack/live/records.json`
holds each one's last result, and `zz_generated.report.md` marks those that
passed `live`. GcpSecretImpersonatedAccount and GcpkmsSecretBackendKey need
real Google Cloud credentials. IdentityMfaPingid skips the drift step: a read returns
nothing its spec sets.

```sh
task live:vault                 # Vault dev server in kind (127.0.0.1:18200, token "hfl-live-dev-root-7c1e"), every kind, records.json
task live:sandbox:vault         # just the server, with the samples' mounts, to apply samples by hand
task live:sandbox:vault:down    # delete it
```

## How it works

The kinds are generated, not hand-written. `hack/gen/vendor.yaml` pins
Vault's OpenAPI spec; [krm-rest-runtime](https://github.com/highfivelabs/krm-rest-runtime)'s
generator finds every resource the API exposes in a create/read/update/delete
shape, keeps those that stand in for a Terraform resource in the gap list
(`hack/gen/terraform-gaps.json`), and writes:

- `types.yaml`: per kind, its API calls, path parameters and Terraform equivalents
- `config/crds/`: one CRD per kind, its spec the API's request body
- `zz_generated.report.md`: the full list

One generic manager (`cmd/manager`) runs every kind on krm-rest-runtime's
reconciler: it creates the resource, reads it back every 10 minutes and
puts back anything changed outside Kubernetes, and deletes it with the
object. Spec fields keep Vault's own names, so the API reference
applies field for field. Path parameters are spec fields too.

Hand corrections to the automatic matching (a Terraform type matched to
the wrong API path, or not matched) are in `vendor.yaml`'s `overrides`.

Vault's OpenAPI document describes only what was mounted on the server that
generated it, and Enterprise system endpoints only as bodiless
`enterprise-stub-*` operations. What it lacks is described by hand in
`hack/gen/supplement/*.yaml` (OpenAPI 3, one file per engine or auth method,
each citing the Vault API docs and terraform-provider-vault source it was
written from), listed after the vendor's spec under `specs:` in
`vendor.yaml`. The generator reads them like the vendor's own.

## Install

```sh
kubectl kustomize config/default | KO_DOCKER_REPO=<registry> ko resolve -f - | kubectl apply --server-side -f -
```

Then, in each namespace that manages Vault, a Secret with
`token` and a Connection named `default`
(`config/samples/connection.yaml`). Objects use it unless
`spec.connectionRef.name` names another. Secret values (tokens, passwords,
secret values) go in a Kubernetes Secret, not the spec:
`spec.secretRefs: {<field>: {name, key}}` fills that body field.

To run only some API groups, install those groups' CRDs from `config/crds`
and pass `--groups` to the manager.

## Kinds

| Kind | Terraform equivalent | Shape | Read |
| --- | --- | --- | --- |
| `activation.vault.hfl.dev/v1alpha1` `ActivationFlag` | `vault_activation_flags` | settings | `GET /sys/activation-flags` (finds `feature`) |
| `agent.vault.hfl.dev/v1alpha1` `AgentRegistration` | `vault_agent_registration` | crud | `GET /agent-registry/registration/id/{id}` |
| `alicloud.vault.hfl.dev/v1alpha1` `AlicloudSecretBackend` | `vault_alicloud_secret_backend` | upsert | `GET /{alicloud_mount_path}/config` |
| `alicloud.vault.hfl.dev/v1alpha1` `AlicloudSecretBackendRole` | `vault_alicloud_secret_backend_role` | upsert | `GET /{alicloud_mount_path}/role/{name}` |
| `approle.vault.hfl.dev/v1alpha1` `ApproleAuthBackendRoleCustomSecretId` | `vault_approle_auth_backend_role_secret_id` | crud | `POST /auth/{approle_mount_path}/role/{role_name}/secret-id-accessor/lookup` |
| `approle.vault.hfl.dev/v1alpha1` `ApproleAuthBackendRoleSecretId` | `vault_approle_auth_backend_role_secret_id` | crud | `POST /auth/{approle_mount_path}/role/{role_name}/secret-id-accessor/lookup` |
| `aws.vault.hfl.dev/v1alpha1` `AwsAuthBackendCert` | `vault_aws_auth_backend_cert` | upsert | `GET /auth/{aws_mount_path}/config/certificate/{cert_name}` |
| `aws.vault.hfl.dev/v1alpha1` `AwsAuthBackendIdentityWhitelist` | `vault_aws_auth_backend_identity_whitelist` | upsert | `GET /auth/{aws_mount_path}/config/tidy/identity-whitelist` |
| `aws.vault.hfl.dev/v1alpha1` `AwsAuthBackendRoletagBlacklist` | `vault_aws_auth_backend_roletag_blacklist` | upsert | `GET /auth/{aws_mount_path}/roletag-blacklist/{role_tag}` |
| `aws.vault.hfl.dev/v1alpha1` `AwsAuthBackendStsRole` | `vault_aws_auth_backend_sts_role` | upsert | `GET /auth/{aws_mount_path}/config/sts/{account_id}` |
| `aws.vault.hfl.dev/v1alpha1` `AwsSecretBackendStaticRole` | `vault_aws_secret_backend_static_role` | upsert | `GET /{aws_mount_path}/static-roles/{name}` |
| `azure.vault.hfl.dev/v1alpha1` `AzureSecretBackendStaticRole` | `vault_azure_secret_backend_static_role` | upsert | `GET /{azure_mount_path}/static-roles/{name}` |
| `config.vault.hfl.dev/v1alpha1` `ConfigControlGroup` | `vault_config_control_group` | upsert | `GET /sys/config/control-group` |
| `config.vault.hfl.dev/v1alpha1` `ConfigGroupPolicyApplication` | `vault_config_group_policy_application` | settings | `GET /sys/config/group-policy-application` |
| `config.vault.hfl.dev/v1alpha1` `ConfigUiCustomMessage` | `vault_config_ui_custom_messages` | crud | `GET /sys/config/ui/custom-messages/{id}` |
| `config.vault.hfl.dev/v1alpha1` `ConfigUiDefaultAuth` | `vault_config_ui_default_auth` | upsert | `GET /sys/config/ui/login/default-auth/{name}` |
| `config.vault.hfl.dev/v1alpha1` `ConfigUiHeader` | `vault_config_ui_header` | upsert | `GET /sys/config/ui/headers/{header}` |
| `database.vault.hfl.dev/v1alpha1` `DatabaseSecretsMount` | `vault_database_secrets_mount` | set | `GET /{path}/config` |
| `egp.vault.hfl.dev/v1alpha1` `EgpPolicy` | `vault_egp_policy` | upsert | `GET /sys/policies/egp/{name}` |
| `gcp.vault.hfl.dev/v1alpha1` `GcpSecretImpersonatedAccount` | `vault_gcp_secret_impersonated_account` | upsert | `GET /{gcp_mount_path}/impersonated-account/{name}` |
| `gcpkms.vault.hfl.dev/v1alpha1` `GcpkmsSecretBackend` | `vault_gcpkms_secret_backend` | upsert | `GET /{gcpkms_mount_path}/config` |
| `gcpkms.vault.hfl.dev/v1alpha1` `GcpkmsSecretBackendKey` | `vault_gcpkms_secret_backend_key` | upsert | `GET /{gcpkms_mount_path}/keys/{key}` |
| `generic.vault.hfl.dev/v1alpha1` `GenericEndpoint` | `vault_generic_endpoint` | upsert | `GET /{+path}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityEntityAssignment` | `vault_identity_entity_policies` | settings | `GET /identity/entity/id/{entity_id}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityGroupAssignment` | `vault_identity_group_member_entity_ids`, `vault_identity_group_member_group_ids`, `vault_identity_group_policies` | settings | `GET /identity/group/id/{group_id}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityMfaDuo` | `vault_identity_mfa_duo` | crud | `GET /identity/mfa/method/duo/{method_id}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityMfaLoginEnforcement` | `vault_identity_mfa_login_enforcement` | upsert | `GET /identity/mfa/login-enforcement/{name}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityMfaOkta` | `vault_identity_mfa_okta` | crud | `GET /identity/mfa/method/okta/{method_id}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityMfaPingid` | `vault_identity_mfa_pingid` | crud | `GET /identity/mfa/method/pingid/{method_id}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityMfaTotp` | `vault_identity_mfa_totp` | crud | `GET /identity/mfa/method/totp/{method_id}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityOidcKeyAllowedClientId` | `vault_identity_oidc_key_allowed_client_id` | upsert | `GET /identity/oidc/key/{name}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityTpm` | `vault_identity_tpm` | upsert | `GET /identity/tpm/name/{name}` |
| `identity.vault.hfl.dev/v1alpha1` `IdentityTpmGroup` | `vault_identity_tpm_group` | crud | `GET /identity/tpmgroup/id/{id}` |
| `keymgmt.vault.hfl.dev/v1alpha1` `KeymgmtDistributeKey` | `vault_keymgmt_distribute_key` | upsert | `GET /{keymgmt_mount_path}/kms/{name}/key/{key_name}` |
| `keymgmt.vault.hfl.dev/v1alpha1` `KeymgmtKey` | `vault_keymgmt_key` | upsert | `GET /{keymgmt_mount_path}/key/{name}` |
| `keymgmt.vault.hfl.dev/v1alpha1` `KeymgmtKmsProvider` | `vault_keymgmt_aws_kms`, `vault_keymgmt_azure_kms`, `vault_keymgmt_gcp_kms` | upsert | `GET /{keymgmt_mount_path}/kms/{name}` |
| `kmip.vault.hfl.dev/v1alpha1` `KmipSecretBackend` | `vault_kmip_secret_backend` | settings | `GET /{kmip_mount_path}/config` |
| `kmip.vault.hfl.dev/v1alpha1` `KmipSecretCaGenerated` | `vault_kmip_secret_ca_generated` | upsert | `GET /{kmip_mount_path}/ca/{name}` |
| `kmip.vault.hfl.dev/v1alpha1` `KmipSecretCaImported` | `vault_kmip_secret_ca_imported` | upsert | `GET /{kmip_mount_path}/ca/{name}` |
| `kmip.vault.hfl.dev/v1alpha1` `KmipSecretListener` | `vault_kmip_secret_listener` | upsert | `GET /{kmip_mount_path}/listener/{name}` |
| `kmip.vault.hfl.dev/v1alpha1` `KmipSecretRole` | `vault_kmip_secret_role` | upsert | `GET /{kmip_mount_path}/scope/{scope}/role/{role}` |
| `kmip.vault.hfl.dev/v1alpha1` `KmipSecretScope` | `vault_kmip_secret_scope` | upsert | `GET /{kmip_mount_path}/scope` |
| `kv.vault.hfl.dev/v1alpha1` `KvSecret` | `vault_generic_secret`, `vault_kv_secret` | upsert | `GET /{kv_v1_mount_path}/{path}` |
| `kv.vault.hfl.dev/v1alpha1` `KvSecretBackendV2` | `vault_kv_secret_backend_v2` | settings | `GET /{kv_v2_mount_path}/config` |
| `ldap.vault.hfl.dev/v1alpha1` `LdapAuthBackendUser` | `vault_ldap_auth_backend_user` | upsert | `GET /auth/{ldap_mount_path}/users/{name}` |
| `ldap.vault.hfl.dev/v1alpha1` `LdapSecretBackendLibrarySet` | `vault_ad_secret_backend_library`, `vault_ldap_secret_backend_library_set` | upsert | `GET /{ldap_mount_path}/library/{name}` |
| `managed.vault.hfl.dev/v1alpha1` `ManagedKey` | `vault_managed_keys` | upsert | `GET /sys/managed-keys/{type}/{name}` |
| `mfa.vault.hfl.dev/v1alpha1` `MfaDuo` | `vault_mfa_duo` | upsert | `GET /sys/mfa/method/duo/{name}` |
| `mfa.vault.hfl.dev/v1alpha1` `MfaOkta` | `vault_mfa_okta` | upsert | `GET /sys/mfa/method/okta/{name}` |
| `mfa.vault.hfl.dev/v1alpha1` `MfaPingid` | `vault_mfa_pingid` | upsert | `GET /sys/mfa/method/pingid/{name}` |
| `mfa.vault.hfl.dev/v1alpha1` `MfaTotp` | `vault_mfa_totp` | upsert | `GET /sys/mfa/method/totp/{name}` |
| `oauth.vault.hfl.dev/v1alpha1` `OauthResourceServerConfigProfile` | `vault_oauth_resource_server_config_profile` | upsert | `GET /sys/config/oauth-resource-server/{name}` |
| `okta.vault.hfl.dev/v1alpha1` `OktaAuthBackendUser` | `vault_okta_auth_backend_user` | upsert | `GET /auth/{okta_mount_path}/users/{name}` |
| `os.vault.hfl.dev/v1alpha1` `OsSecretBackend` | `vault_os_secret_backend` | settings | `GET /{os_mount_path}/config` |
| `os.vault.hfl.dev/v1alpha1` `OsSecretBackendAccount` | `vault_os_secret_backend_account` | upsert | `GET /{os_mount_path}/hosts/{host_ref}/accounts/{name}` |
| `os.vault.hfl.dev/v1alpha1` `OsSecretBackendHost` | `vault_os_secret_backend_host` | upsert | `GET /{os_mount_path}/hosts/{name}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiExternalCaSecretBackendAcmeAccount` | `vault_pki_external_ca_secret_backend_acme_account` | upsert | `GET /{pki_external_ca_mount_path}/config/acme-account/{name}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiExternalCaSecretBackendDnsProviderAwsRoute53` | `vault_pki_external_ca_secret_backend_dns_provider_aws_route53` | upsert | `GET /{pki_external_ca_mount_path}/config/dns/aws-route53/{name}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiExternalCaSecretBackendDnsProviderAzure` | `vault_pki_external_ca_secret_backend_dns_provider_azure` | upsert | `GET /{pki_external_ca_mount_path}/config/dns/azure-dns/{name}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiExternalCaSecretBackendDnsProviderGcp` | `vault_pki_external_ca_secret_backend_dns_provider_gcp` | upsert | `GET /{pki_external_ca_mount_path}/config/dns/google-cloud-dns/{name}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiExternalCaSecretBackendDnsProviderRfc2136` | `vault_pki_external_ca_secret_backend_dns_provider_rfc2136` | upsert | `GET /{pki_external_ca_mount_path}/config/dns/rfc2136/{name}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiExternalCaSecretBackendOrder` | `vault_pki_external_ca_secret_backend_order` | crud | `GET /{pki_external_ca_mount_path}/role/{name}/order/{id}/status` |
| `pki.vault.hfl.dev/v1alpha1` `PkiExternalCaSecretBackendRole` | `vault_pki_external_ca_secret_backend_role` | upsert | `GET /{pki_external_ca_mount_path}/role/{name}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendAcmeEab` | `vault_pki_secret_backend_acme_eab` | crud | `GET /{pki_mount_path}/eab/` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendConfigAcme` | `vault_pki_secret_backend_config_acme` | settings | `GET /{pki_mount_path}/config/acme` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendConfigAutoTidy` | `vault_pki_secret_backend_config_auto_tidy` | settings | `GET /{pki_mount_path}/config/auto-tidy` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendConfigCa` | `vault_pki_secret_backend_config_ca` | crud | `GET /{pki_mount_path}/issuer/{issuer_ref}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendConfigCluster` | `vault_pki_secret_backend_config_cluster` | settings | `GET /{pki_mount_path}/config/cluster` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendConfigCmpv2` | `vault_pki_secret_backend_config_cmpv2` | settings | `GET /{pki_mount_path}/config/cmp` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendConfigEst` | `vault_pki_secret_backend_config_est` | settings | `GET /{pki_mount_path}/config/est` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendConfigIssuers` | `vault_pki_secret_backend_config_issuers` | settings | `GET /{pki_mount_path}/config/issuers` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendConfigScep` | `vault_pki_secret_backend_config_scep` | settings | `GET /{pki_mount_path}/config/scep` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendCrlConfig` | `vault_pki_secret_backend_crl_config` | settings | `GET /{pki_mount_path}/config/crl` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendExportKey` | `vault_pki_secret_backend_export_key` | crud | `GET /{pki_mount_path}/export/{id}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendIntermediateCertRequest` | `vault_pki_secret_backend_intermediate_cert_request` | crud | `GET /{pki_mount_path}/key/{key_ref}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendIntermediateSetSigned` | `vault_pki_secret_backend_intermediate_set_signed` | crud | `GET /{pki_mount_path}/issuer/{issuer_ref}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendIssuer` | `vault_pki_secret_backend_issuer` | upsert | `GET /{pki_mount_path}/issuer/{issuer_ref}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendKey` | `vault_pki_secret_backend_key` | upsert | `GET /{pki_mount_path}/key/{key_ref}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendRootCert` | `vault_pki_secret_backend_root_cert` | crud | `GET /{pki_mount_path}/issuer/{issuer_ref}` |
| `pki.vault.hfl.dev/v1alpha1` `PkiSecretBackendWrappedKeyImport` | `vault_pki_secret_backend_wrapped_key_import` | crud | `GET /{pki_mount_path}/key/{id}` |
| `plugin.vault.hfl.dev/v1alpha1` `Plugin` | `vault_plugin` | upsert | `GET /sys/plugins/catalog/{type}/{name}` |
| `plugin.vault.hfl.dev/v1alpha1` `PluginPinnedVersion` | `vault_plugin_pinned_version` | upsert | `GET /sys/plugins/pins/{type}/{name}` |
| `plugin.vault.hfl.dev/v1alpha1` `PluginRuntime` | `vault_plugin_runtime` | upsert | `GET /sys/plugins/runtimes/catalog/{type}/{name}` |
| `radius.vault.hfl.dev/v1alpha1` `RadiusAuthBackendUser` | `vault_radius_auth_backend_user` | upsert | `GET /auth/{radius_mount_path}/users/{name}` |
| `raft.vault.hfl.dev/v1alpha1` `RaftAutopilot` | `vault_raft_autopilot` | settings | `GET /sys/storage/raft/autopilot/configuration` |
| `raft.vault.hfl.dev/v1alpha1` `RaftSnapshotAgentConfig` | `vault_raft_snapshot_agent_config` | upsert | `GET /sys/storage/raft/snapshot-auto/config/{name}` |
| `rgp.vault.hfl.dev/v1alpha1` `RgpPolicy` | `vault_rgp_policy` | upsert | `GET /sys/policies/rgp/{name}` |
| `saml.vault.hfl.dev/v1alpha1` `SamlAuthBackend` | `vault_saml_auth_backend` | settings | `GET /auth/{saml_mount_path}/config` |
| `saml.vault.hfl.dev/v1alpha1` `SamlAuthBackendRole` | `vault_saml_auth_backend_role` | upsert | `GET /auth/{saml_mount_path}/role/{name}` |
| `scep.vault.hfl.dev/v1alpha1` `ScepAuthBackendRole` | `vault_scep_auth_backend_role` | upsert | `GET /auth/{scep_mount_path}/role/{name}` |
| `scim.vault.hfl.dev/v1alpha1` `ScimClient` | `vault_scim_client` | upsert | `GET /identity/scim/client/{client_name}` |
| `secrets.vault.hfl.dev/v1alpha1` `SecretsSyncAssociation` | `vault_secrets_sync_association` | upsert | `GET /sys/sync/associations/destinations` (finds `{type}/{name}`) |
| `secrets.vault.hfl.dev/v1alpha1` `SecretsSyncAwsDestination` | `vault_secrets_sync_aws_destination` | upsert | `GET /sys/sync/destinations/aws-sm/{name}` |
| `secrets.vault.hfl.dev/v1alpha1` `SecretsSyncAzureDestination` | `vault_secrets_sync_azure_destination` | upsert | `GET /sys/sync/destinations/azure-kv/{name}` |
| `secrets.vault.hfl.dev/v1alpha1` `SecretsSyncConfig` | `vault_secrets_sync_config` | settings | `GET /sys/sync/config` |
| `secrets.vault.hfl.dev/v1alpha1` `SecretsSyncGcpDestination` | `vault_secrets_sync_gcp_destination` | upsert | `GET /sys/sync/destinations/gcp-sm/{name}` |
| `secrets.vault.hfl.dev/v1alpha1` `SecretsSyncGhDestination` | `vault_secrets_sync_gh_destination` | upsert | `GET /sys/sync/destinations/gh/{name}` |
| `secrets.vault.hfl.dev/v1alpha1` `SecretsSyncGithubApp` | `vault_secrets_sync_github_apps` | upsert | `GET /sys/sync/github-apps/{name}` |
| `secrets.vault.hfl.dev/v1alpha1` `SecretsSyncVercelDestination` | `vault_secrets_sync_vercel_destination` | upsert | `GET /sys/sync/destinations/vercel-project/{name}` |
| `spiffe.vault.hfl.dev/v1alpha1` `SpiffeAuthBackendConfig` | `vault_spiffe_auth_backend_config` | settings | `GET /auth/{spiffe_mount_path}/config` |
| `spiffe.vault.hfl.dev/v1alpha1` `SpiffeAuthBackendRole` | `vault_spiffe_auth_backend_role` | upsert | `GET /auth/{spiffe_mount_path}/role/{name}` |
| `spiffe.vault.hfl.dev/v1alpha1` `SpiffeSecretBackendConfig` | `vault_spiffe_secret_backend_config` | settings | `GET /{spiffe_mount_path}/config` |
| `spiffe.vault.hfl.dev/v1alpha1` `SpiffeSecretBackendRole` | `vault_spiffe_secret_backend_role` | upsert | `GET /{spiffe_mount_path}/role/{name}` |
| `sys.vault.hfl.dev/v1alpha1` `SysConfigCors` | `vault_sys_config_cors` | upsert | `GET /sys/config/cors` |
| `token.vault.hfl.dev/v1alpha1` `Token` | `vault_token` | crud | `POST /auth/token/lookup-accessor` |
| `token.vault.hfl.dev/v1alpha1` `TokenAuthBackendRole` | `vault_token_auth_backend_role` | upsert | `GET /auth/token/roles/{role_name}` |
| `tpm.vault.hfl.dev/v1alpha1` `TpmAuthBackendConfig` | `vault_tpm_auth_backend_config` | settings | `GET /auth/{tpm_mount_path}/config` |
| `tpm.vault.hfl.dev/v1alpha1` `TpmAuthBackendRole` | `vault_tpm_auth_backend_role` | upsert | `GET /auth/{tpm_mount_path}/role/{name}` |
| `transform.vault.hfl.dev/v1alpha1` `TransformAlphabet` | `vault_transform_alphabet` | upsert | `GET /{transform_mount_path}/alphabet/{name}` |
| `transform.vault.hfl.dev/v1alpha1` `TransformKeyConfiguration` | `vault_transform_key_configuration` | settings | `GET /{transform_mount_path}/tokenization/keys/{name}` |
| `transform.vault.hfl.dev/v1alpha1` `TransformRole` | `vault_transform_role` | upsert | `GET /{transform_mount_path}/role/{name}` |
| `transform.vault.hfl.dev/v1alpha1` `TransformTemplate` | `vault_transform_template` | upsert | `GET /{transform_mount_path}/template/{name}` |
| `transform.vault.hfl.dev/v1alpha1` `TransformTransformation` | `vault_transform_transformation` | upsert | `GET /{transform_mount_path}/transformation/{name}` |
| `transform.vault.hfl.dev/v1alpha1` `TransformTransformationTokenization` | `vault_transform_transformation_tokenization` | upsert | `GET /{transform_mount_path}/transformations/tokenization/{name}` |
| `transform.vault.hfl.dev/v1alpha1` `TransformTransformationTokenizationStore` | `vault_transform_transformation_tokenization_store` | upsert | `GET /{transform_mount_path}/stores/{name}` |
| `transit.vault.hfl.dev/v1alpha1` `TransitSecretBackendCacheConfig` | `vault_transit_secret_backend_cache_config` | settings | `GET /{transit_mount_path}/cache-config` |
| `userpass.vault.hfl.dev/v1alpha1` `UserpassAuthBackendUser` | `vault_userpass_auth_backend_user` | upsert | `GET /auth/{userpass_mount_path}/users/{username}` |

## Not covered

<!-- BEGIN generated: not covered (krmgen.py, from vendor.yaml hardBlocks and draftNotes) -->
13 of the 135 Terraform gap types have no kind: 13 are not built (`hardBlocks` in `hack/gen/vendor.yaml`).

| Terraform | Status | Why |
| --- | --- | --- |
| `vault_ad_secret_backend` | not built | Removed from Vault: the Active Directory secrets engine is under "Removed" on Vault's deprecation page (announced March 2023, removal CY25 Q1); `vault_ldap_secret_backend` and its static roles replace it. |
| `vault_ad_secret_role` | not built | Removed from Vault: the Active Directory secrets engine is under "Removed" on Vault's deprecation page (announced March 2023, removal CY25 Q1); `vault_ldap_secret_backend` and its static roles replace it. |
| `vault_approle_auth_backend_login` | not built | A login, which issues a token (Terraform keeps the token and looks it up); not a resource to manage. |
| `vault_aws_auth_backend_login` | not built | A login, which issues a token (Terraform keeps the token and looks it up); not a resource to manage. |
| `vault_aws_auth_backend_role_tag` | not built | `POST .../role/:role/tag` answers a signed tag Vault keeps nowhere; Terraform's read and delete do nothing. |
| `vault_keymgmt_key_rotate` | not built | One `POST .../rotate` or `.../replicate`; Terraform's destroy does nothing ("rotation is permanent", "replication is not a physical resource"). |
| `vault_keymgmt_replicate_key` | not built | One `POST .../rotate` or `.../replicate`; Terraform's destroy does nothing ("rotation is permanent", "replication is not a physical resource"). |
| `vault_pki_external_ca_secret_backend_order_certificate` | not built | A lookup (`GET .../order/:id/fetch-cert` of a completed order); it writes nothing. |
| `vault_pki_external_ca_secret_backend_order_challenge_fulfilled` | not built | One `POST .../fulfilled-challenge`; Terraform reads and deletes nothing. |
| `vault_pki_secret_backend_cert` | not built | Issues a certificate (`.../issue/:role`, `.../sign/:role`, `.../root/sign-intermediate`); Terraform reads nothing back (only checks the mount and its renewal window) and revokes on destroy if asked. |
| `vault_pki_secret_backend_root_sign_intermediate` | not built | Issues a certificate (`.../issue/:role`, `.../sign/:role`, `.../root/sign-intermediate`); Terraform reads nothing back (only checks the mount and its renewal window) and revokes on destroy if asked. |
| `vault_pki_secret_backend_sign` | not built | Issues a certificate (`.../issue/:role`, `.../sign/:role`, `.../root/sign-intermediate`); Terraform reads nothing back (only checks the mount and its renewal window) and revokes on destroy if asked. |
| `vault_terraform_cloud_secret_creds` | not built | `GET .../creds/:role` issues an HCP Terraform token under a lease; Terraform looks the lease up and revokes it. Not a resource to manage. |
<!-- END generated: not covered -->

A root CA (`PkiSecretBackendRootCert`) is the issuer Vault makes: deleting
the object deletes that issuer (`DELETE .../issuer/:id`), not the mount's
whole CA as Terraform's `DELETE .../root` did before multiple issuers.
`PkiSecretBackendConfigCa` and `PkiSecretBackendIntermediateSetSigned` are
read as the first issuer their import made, and
`PkiSecretBackendIntermediateCertRequest` as the key it made (its CSR and,
`exported`, private key go to `spec.writeSecretRef`); like Terraform's
resources, deleting them leaves what they made. An AppRole SecretID is
`ApproleAuthBackendRoleSecretId` (Vault makes it; it goes to
`spec.writeSecretRef`) or `ApproleAuthBackendRoleCustomSecretId` (you set
it); response wrapping (`wrapping_ttl`) is not covered. `GenericEndpoint`
writes any path (`spec.path`, the other spec fields its body), compares
only what the read answers, and always reads and deletes the path
(Terraform's `disable_read` and `disable_delete` have no counterpart).

`Token` (`vault_token`) makes a token with `POST /auth/token/create`; the
token is answered once and goes to `spec.writeSecretRef`. It is read back
by `POST /auth/token/lookup-accessor` and revoked with the object. Only
what the lookup answers as written is compared (`meta`, `renewable`,
`type`); the rest is sent once. It is not renewed (Terraform's
`renew_min_lease`), cannot be made with a token role
(`/auth/token/create/:role_name`), and a change to any field means a new
token: delete and re-create the object.

`DatabaseSecretsMount` (`vault_database_secrets_mount`) makes the mount
(`type: database`) and holds every connection in it: one in the mount and
not in the spec is deleted, and deleting the object deletes the mount and
its connections. The mount's own fields are set only when it is made.
Connections' passwords are in the spec (`spec.secretRefs` fills only
top-level fields). The same desired state is also vault-config-operator's
SecretEngineMount and DatabaseSecretEngineConfig: use one or the other for
a mount.

## Reading back

A read that gives a field back in another form than it was written is not
compared: the field is sent again only when the spec changes. Vault sorts
and lowercases some lists: write the LDAP and RADIUS users' `policies`
(and the Google Cloud KMS engine's `scopes`) sorted and in lower case, or
every resync sees drift and writes them again. The KV version 2 engine
reads `delete_version_after` back in Go's long form: write `1h0m0s`, not
`1h`.

## For agents (MCP)

`cmd/mcp` serves this repository's kinds over the Model Context Protocol
(stdio), from `types.yaml`, `config/crds` and the live tests' records.
`.mcp.json` registers it, so an agent session opened in this repository
has it without setup. Elsewhere, run it from the repository root:

```sh
go run ./cmd/mcp
```

Its tools: `list_kinds`, `find_kinds_for_terraform`, `describe_kind` (every
field, the REST calls, the live record), `example` (the live-tested spec
where there is one), `validate_manifest` (the CRD schema, as the API server
checks it) and `plan_on_fake` (the controller run against the fake API,
with every REST call it makes). Nothing it does reaches the real API.
krm-rest-runtime's README ("For agents") has the details.

## Regenerate

```sh
hack/gen/generate.sh   # needs python3 + pyyaml, and krm-rest-runtime beside this repo
go test ./...
```
