# Mail server automation Makefile
#
# Targets interact with the Ansible playbook to provision and manage the
# Postfix + Dovecot + MariaDB stack for IPv6 address-literal mail routing.

ANSIBLE_PLAYBOOK ?= ansible-playbook
INVENTORY ?= ansible/inventory/hosts.ini
PLAYBOOK ?= ansible/site.yml

.PHONY: install configure db-init postfix dovecot test cleanup

# Install required packages on the managed host(s).
install:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --tags install

# Apply full configuration, including packages, services, database schema,
# and configuration files.
configure:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK)

# Initialize or update the MariaDB schema and seed data only.
db-init:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --tags db

# Refresh only Postfix configuration and reload the service.
postfix:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --tags postfix

# Refresh only Dovecot configuration and reload the service.
dovecot:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --tags dovecot

# Run post-deployment functional checks using the provided test script.
test:
	./test_mail_ipv6.sh

# Remove generated artifacts and tear down mail storage (non-destructive to
# system packages but clears mail data for lab rebuilds).
cleanup:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PLAYBOOK) --tags cleanup
