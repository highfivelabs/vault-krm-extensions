// Copyright 2026 High Five Labs
// SPDX-License-Identifier: Apache-2.0

package extensions

import (
	"net/http"
	"strings"

	"github.com/highfivelabs/krm-rest-runtime/rest"
)

// Vendor is how the manager reaches Vault.
var Vendor = &rest.Vendor{
	Name:           "vault",
	DefaultBaseURL: "", // every Connection names its Vault
	CredentialKeys: []string{"token"},
	Authorize: func(r *http.Request, c map[string]string) {
		r.Header.Set("X-Vault-Token", c["token"])
		if ns := c["namespace"]; ns != "" {
			r.Header.Set("X-Vault-Namespace", ns)
		}
	},
	// A read of a PKI issuer or key that does not exist (deleted, or never
	// made) is an HTTP 500 naming the reference, not a 404. A Google Cloud
	// KMS engine's read or delete of a key it does not hold is an HTTP 400
	// (vault-plugin-secrets-gcpkms: ErrKeyNotFound as an invalid request), as
	// is a lookup of a token accessor that is revoked or expired.
	NotFound: func(status int, body []byte) bool {
		b := string(body)
		switch status {
		case http.StatusInternalServerError:
			return strings.Contains(b, "unable to find PKI issuer for reference") || strings.Contains(b, "unable to find PKI key for reference")
		case http.StatusBadRequest:
			// A revoked or expired token's accessor (terraform-provider-vault
			// util.IsExpiredTokenErr).
			return strings.Contains(b, "encryption key not found") || strings.Contains(b, "invalid accessor") ||
				strings.Contains(b, "failed to find accessor entry")
		}
		return false
	},
}
