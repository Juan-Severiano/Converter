# Signed macOS releases

The `Release DMG` workflow builds the `Converter` scheme, signs it with a Developer ID Application certificate, submits the DMG to Apple for notarization, staples the accepted ticket, and publishes a GitHub release. It runs when a `v*` tag is pushed or manually from the Actions page.

## One-time Apple setup

Create the **Developer ID Application** certificate from Xcode: **Settings → Accounts → Manage Certificates → + → Developer ID Application**. Creating it in Xcode ensures that the certificate and private key are paired. Export the certificate item (not its child key) from Keychain Access → My Certificates as a password-protected `.p12`.

Before adding it to GitHub, verify the export includes both pieces:

```bash
openssl pkcs12 -in developer_id.p12 -nodes -passin pass:'P12_PASSWORD' -legacy 2>&1 > /tmp/convert-certificate.pem
grep -c "BEGIN CERTIFICATE\|BEGIN PRIVATE KEY" /tmp/convert-certificate.pem
```

The command must print `2`. A result of `1` means the export is unusable in CI; recreate and export the certificate again from Xcode.

Create an App Store Connect API key with notarization access at **Users and Access → Integrations → API Keys**, and download its `.p8` file. Keep the `.p12`, its password, and the `.p8` private key out of the repository.

## GitHub Actions secrets

Set these repository secrets before the first release. The local repository currently has no `origin` remote, so create or connect its GitHub repository before setting them.

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID (`JX5SC3F52Q` for this project) |
| `DEVELOPER_ID_APPLICATION` | Exact certificate name, such as `Developer ID Application: Name (TEAMID)` |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` |
| `P12_PASSWORD` | Password chosen when exporting the `.p12` |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API issuer ID |
| `APPLE_API_KEY_BASE64` | Base64-encoded `AuthKey_*.p8` file |

With GitHub CLI authenticated, replace `OWNER/REPO` with the destination repository and set them without writing secret material to a shell history:

```bash
gh secret set APPLE_TEAM_ID -R OWNER/REPO -b 'JX5SC3F52Q'
gh secret set DEVELOPER_ID_APPLICATION -R OWNER/REPO
gh secret set BUILD_CERTIFICATE_BASE64 -R OWNER/REPO < <(base64 -i developer_id.p12)
gh secret set P12_PASSWORD -R OWNER/REPO
gh secret set APPLE_API_KEY_ID -R OWNER/REPO
gh secret set APPLE_API_ISSUER_ID -R OWNER/REPO
gh secret set APPLE_API_KEY_BASE64 -R OWNER/REPO < <(base64 -i AuthKey_XXXXXXXXXX.p8)
```

## Releasing

Push a version tag to publish a normal release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or start **Release DMG** manually in GitHub Actions and supply a tag. The workflow uploads `Convert-<version>.dmg` as both the run artifact and the GitHub release asset. Re-running a published tag replaces the DMG asset rather than creating a duplicate release.

The normal `CI` workflow runs unsigned for every push and pull request, so certificate and notarization secrets are never needed for ordinary validation.
