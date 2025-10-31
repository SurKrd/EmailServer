# Closed-Network IPv6 Literal Mail Service

This deployment bundles automation and configuration for a Postfix + Dovecot + MariaDB
mail service that routes mail based entirely on IPv6 address-literals. It is intended for
laboratory or mission-network environments where name services are unavailable and
all transport occurs inside a trusted IPv6-only segment.

## Why address-literals?

RFC 5321 §4.1.3 permits mail addresses of the form `user@[IPv6:2001:db8::1]`. In a
closed network without DNS, IPv6 literals become the only stable identifier. This
build accepts messages addressed to `user@[IPv6:af49::XXXX]`, rewrites them to the
internal domain `internal.invalid`, and delivers them through Dovecot-managed
Maildir hierarchies.

Key design points:

- **No external dependencies:** All routing, authentication, and delivery decisions
  rely on local configuration and MariaDB, avoiding DNS or Internet connectivity.
- **Deterministic rewrites:** A Postfix regular expression map converts literals
  into canonical mailbox names that Dovecot and MariaDB understand.
- **Auditable deliveries:** The original literal recipient is preserved in the
  `X-Original-To` header so operators can trace the initial envelope address.

## Components

| Component | Role |
|-----------|------|
| Postfix   | Receives SMTP on IPv6, rewrites literals, performs SASL authentication via Dovecot, and relays mail to Dovecot over LMTP. |
| Dovecot   | Provides IMAP and LMTP services, authenticates users against MariaDB, and stores messages in Maildir format under `/var/mail/vhosts/internal.invalid/`. |
| MariaDB   | Stores virtual domains, users, and aliases. Includes one seeded test user (`alice@[IPv6:af49::10]`). |
| Ansible   | Applies the entire stack idempotently and manages configuration files. Install `community.mysql` via `ansible-galaxy collection install -r ansible/requirements.yml`. |
| Makefile  | Shortcut targets to run Ansible tasks and execute functional tests. |

## Address normalization workflow

1. A client submits a message to `user@[IPv6:af49::10]`.
2. Postfix matches the recipient against `/etc/postfix/virtual_ip_literals`:
   ```
   /^(.+)@\[(?:IPv6:)?af49::([0-9A-Fa-f:]+)\]$/  ${1}+IPv6-af49--${2}@internal.invalid
   ```
3. The literal address becomes `user+IPv6-af49--10@internal.invalid`.
4. Postfix verifies the recipient through `mysql-virtual-mailbox-maps.cf`, which
   ensures the rewritten address exists in `virtual_users`.
5. Postfix hands the message to Dovecot over `lmtp:unix:private/dovecot-lmtp`.
6. Dovecot reads the matching row from MariaDB, expands the path
   `/var/mail/vhosts/internal.invalid/user+IPv6-af49--10/Maildir`, and writes the message.
7. The message retains the header `X-Original-To: user@[IPv6:af49::10]` for auditing.

## Extending to other subnets

- **Additional IPv6 ranges:** Duplicate the regex line in
  `/etc/postfix/virtual_ip_literals`, adjusting the literal prefix and the marker
  used in the rewritten local part (e.g., replace `af49` with the new 16-bit
  identifier). Add corresponding rows to `virtual_users` for each mailbox.
- **IPv4 literals:** RFC 5321 also allows IPv4 address-literals (`user@[192.0.2.10]`).
  Add another regex line such as:
  ```
  /^(.+)@\[(?:IPv4:)?10\.0\.0\.([0-9]{1,3})\]$/  ${1}+IPv4-10-0-0-${2}@internal.invalid
  ```
  Ensure MariaDB includes the rewritten address and that filesystem-safe
  delimiters replace dots.

## Security considerations

- **Relay restrictions:** `mynetworks` is limited to `af49::/16` and loopback, and
  unauthenticated clients outside this range are rejected. SASL authentication via
  Dovecot is still available for hosts that cannot rely on source-based trust.
- **TLS:** Disabled intentionally; enable STARTTLS with an internal CA if traffic
  confidentiality is required even within the closed environment.
- **Database credentials:** The default MariaDB user (`mailuser`) and password are
  stored in plaintext configuration files. Rotate them during deployment and update
  the Ansible variables as appropriate.
- **System isolation:** The LMTP and auth sockets are exposed only within
  `/var/spool/postfix/private`, ensuring unprivileged processes cannot access them.

## Operational workflow

1. `make install` — install prerequisite packages.
2. `make configure` — apply full configuration and seed the database.
3. `make test` — run `test_mail_ipv6.sh` to send a loopback message and verify delivery.
4. `make cleanup` — remove `/var/mail/vhosts` if you need to reset stored mail for
   lab exercises.

The Ansible playbook expects `ansible-galaxy collection install -r ansible/requirements.yml`
to be executed at least once on the control node.

For manual database provisioning, run `mysql < mariadb/init.sql` after securing the
MariaDB root account. Additional users can be inserted by following the pattern in
`init.sql`, replacing the IPv6 suffix in both the literal and rewritten forms.
