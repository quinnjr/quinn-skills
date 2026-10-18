# OWASP Top 10 (2021) — Reference with CWE Cross-References

Use this to classify findings by OWASP category and associated CWEs.

## A01:2021 — Broken Access Control
Failures in enforcing that users cannot act outside their intended permissions.

**CWEs**: CWE-200, CWE-201, CWE-352, CWE-284, CWE-285, CWE-639, CWE-862, CWE-863, CWE-913

- IDOR (Insecure Direct Object References) — CWE-639
- Missing authorization checks on endpoints — CWE-862
- Privilege escalation (horizontal and vertical) — CWE-269
- CORS misconfiguration allowing unauthorized access — CWE-942
- Metadata manipulation (tampering with JWT, cookies, hidden fields) — CWE-565
- Path traversal to access files outside intended directory — CWE-22
- Missing function-level access control — CWE-285
- CSRF (Cross-Site Request Forgery) — CWE-352
- Force browsing to unauthenticated pages — CWE-425

## A02:2021 — Cryptographic Failures
Failures related to cryptography leading to sensitive data exposure.

**CWEs**: CWE-259, CWE-261, CWE-296, CWE-310, CWE-319, CWE-321, CWE-326, CWE-327, CWE-328, CWE-329, CWE-330, CWE-331, CWE-335, CWE-336, CWE-338, CWE-340, CWE-347, CWE-523, CWE-720, CWE-757, CWE-759, CWE-760, CWE-780, CWE-818, CWE-916

- Data transmitted in cleartext (HTTP, FTP, SMTP without TLS) — CWE-319
- Weak, deprecated, or broken algorithms (MD5, SHA1, DES, RC4) — CWE-327, CWE-328
- Hardcoded or default encryption keys — CWE-321, CWE-259
- Missing encryption of sensitive data at rest — CWE-311
- Weak random number generation for security contexts — CWE-330, CWE-338
- Missing certificate validation — CWE-295
- Insufficient key length — CWE-326
- Password stored with reversible encryption — CWE-257
- Nonce/IV reuse — CWE-329
- Missing salt or weak salt in password hashing — CWE-759, CWE-760
- Insufficient password hashing iterations — CWE-916

## A03:2021 — Injection
User-supplied data sent to an interpreter without validation or escaping.

**CWEs**: CWE-20, CWE-74, CWE-75, CWE-77, CWE-78, CWE-79, CWE-80, CWE-83, CWE-87, CWE-88, CWE-89, CWE-90, CWE-91, CWE-93, CWE-94, CWE-95, CWE-96, CWE-97, CWE-98, CWE-116, CWE-138, CWE-184, CWE-470, CWE-471, CWE-564, CWE-610, CWE-643, CWE-644, CWE-652, CWE-917

- SQL injection — CWE-89
- NoSQL injection — CWE-943
- OS command injection — CWE-78
- LDAP injection — CWE-90
- Cross-Site Scripting (XSS) — reflected CWE-79, stored CWE-79, DOM-based CWE-79
- Server-Side Template Injection (SSTI) — CWE-94
- Expression Language injection — CWE-917
- Header injection / CRLF injection — CWE-93, CWE-113
- XPath injection — CWE-643
- XML External Entity (XXE) — CWE-611
- Log injection — CWE-117
- Code injection via eval() — CWE-94, CWE-95

## A04:2021 — Insecure Design
Flaws in the design and architecture rather than the implementation.

**CWEs**: CWE-209, CWE-256, CWE-501, CWE-522, CWE-602, CWE-653, CWE-799, CWE-807, CWE-840, CWE-841, CWE-927

- Missing rate limiting on sensitive operations — CWE-770
- No account lockout mechanism — CWE-307
- Missing business logic validation — CWE-840
- Unrestricted resource consumption — CWE-400
- Lack of defense in depth — CWE-653
- Client-side enforcement of security — CWE-602
- Trust boundary violations — CWE-501
- Insufficient anti-automation — CWE-799
- Race condition in business logic — CWE-362

## A05:2021 — Security Misconfiguration
Insecure default configurations or incomplete/ad-hoc configurations.

**CWEs**: CWE-2, CWE-11, CWE-13, CWE-15, CWE-16, CWE-260, CWE-315, CWE-520, CWE-526, CWE-537, CWE-541, CWE-547, CWE-611, CWE-614, CWE-732, CWE-756, CWE-776, CWE-942, CWE-1004, CWE-1032, CWE-1174

- Debug mode enabled in production — CWE-489
- Unnecessary features enabled (ports, services, pages, accounts) — CWE-1188
- Default accounts with unchanged passwords — CWE-1188
- Stack traces or overly informative error messages — CWE-209
- Missing security headers — CWE-693
- Permissive CORS policies — CWE-942
- Directory listing enabled — CWE-548
- Unnecessary HTTP methods allowed — CWE-749
- XML external entity processing enabled — CWE-611
- Missing cookie flags (Secure, HttpOnly, SameSite) — CWE-614, CWE-1004
- Cloud storage with public access — CWE-732

## A06:2021 — Vulnerable and Outdated Components
Using components with known vulnerabilities.

**CWEs**: CWE-1104, CWE-937

- Dependencies with known CVEs — CWE-1395
- Unsupported or end-of-life software — CWE-1104
- Unpinned dependency versions — CWE-1395
- Not scanning for vulnerabilities regularly
- Missing security patches
- Abandoned or unmaintained dependencies
- Typosquatted package names

## A07:2021 — Identification and Authentication Failures
Weaknesses in authentication mechanisms.

**CWEs**: CWE-255, CWE-259, CWE-287, CWE-288, CWE-290, CWE-294, CWE-295, CWE-297, CWE-300, CWE-302, CWE-304, CWE-306, CWE-307, CWE-346, CWE-384, CWE-521, CWE-613, CWE-620, CWE-640, CWE-798, CWE-940, CWE-1216

- Permits brute force or credential stuffing — CWE-307
- Permits weak or well-known passwords — CWE-521
- Missing or ineffective multi-factor authentication
- Exposes session identifiers in URLs — CWE-598
- Does not properly invalidate sessions on logout — CWE-613
- Plain-text or weakly-hashed passwords — CWE-256, CWE-916
- Session fixation — CWE-384
- JWT algorithm confusion — CWE-345
- Account enumeration — CWE-204
- Default credentials — CWE-798

## A08:2021 — Software and Data Integrity Failures
Failures to protect against integrity violations.

**CWEs**: CWE-345, CWE-353, CWE-426, CWE-494, CWE-502, CWE-565, CWE-784, CWE-829, CWE-830, CWE-915

- Insecure deserialization — CWE-502
- CI/CD pipeline without integrity verification — CWE-494
- Auto-update without signature verification — CWE-494
- Unsigned or unverified dependencies — CWE-829
- Use of untrusted CDN or third-party resources without SRI — CWE-830
- Dependency confusion attacks — CWE-427
- Prototype pollution — CWE-1321
- Mass assignment / auto-binding — CWE-915
- Missing code signing

## A09:2021 — Security Logging and Monitoring Failures
Insufficient logging, detection, or response capability.

**CWEs**: CWE-117, CWE-223, CWE-532, CWE-778

- Auditable events not logged (login, failed login, high-value transactions) — CWE-778
- Logs not monitored for suspicious activity — CWE-223
- Logs stored only locally
- No alerting thresholds or escalation
- Sensitive data in log messages — CWE-532
- Log injection allowing log forgery — CWE-117
- Missing integrity controls on log data
- Insufficient log retention

## A10:2021 — Server-Side Request Forgery (SSRF)
Application fetches a remote resource without validating the user-supplied URL.

**CWEs**: CWE-918

- Fetching URLs from user input without allowlist — CWE-918
- Accessing internal services via user-controlled URLs
- Missing URL scheme validation
- Cloud metadata endpoint access (169.254.169.254)
- DNS rebinding attacks
- Blind SSRF via webhooks/callbacks
- SSRF via PDF generators, image processors, URL preview features
- URL parser differentials enabling bypass
