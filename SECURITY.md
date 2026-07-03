# Security Policy

## Supported Versions

Only the latest released version of pico_phone receives security fixes.

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |

## Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub issues.

Instead, use [GitHub's private vulnerability reporting](https://github.com/gjack/pico_phone/security/advisories/new) to submit a report confidentially. You can expect an acknowledgement within 72 hours and a fix or mitigation plan within 14 days depending on severity.

## Scope

pico_phone is a thin wrapper around Google's [libphonenumber](https://github.com/google/libphonenumber) C++ library. If the vulnerability is in libphonenumber itself rather than in this gem, please report it upstream to the [libphonenumber project](https://github.com/google/libphonenumber/issues) directly.
