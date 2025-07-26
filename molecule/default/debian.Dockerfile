# Dockerfile for debian:latest
# SPDX-License-Identifier: MIT
#
# Built from the following sources:
# - https://github.com/geerlingguy/docker-debian12-ansible/blob/master/Dockerfile
# - https://ansible.readthedocs.io/projects/molecule/guides/systemd-container/
#
# Dockerfile reference: https://docs.docker.com/reference/dockerfile/
FROM debian:latest

# Variables for headless apt usage
ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    sudo coreutils systemd systemd-sysv \
    build-essential wget libffi-dev libssl-dev procps \
    python3 python3-pip python3-dev python3-setuptools python3-wheel python3-apt \
    iproute2 dbus \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean

# Remove externally managed warning
RUN find /usr/lib/ -name "EXTERNALLY-MANAGED" -print0 | xargs -0 rm -f

# Install Ansible via Pip.
RUN python3 -m pip install --user ansible

# Install Ansible inventory file.
RUN mkdir -p /etc/ansible
RUN echo -e "[local]\nlocalhost ansible_connection=local" > /etc/ansible/hosts

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
    && rm -f /lib/systemd/system/getty.target

# Make sure systemd doesn't start agettys on tty[1-6].
RUN rm -f /lib/systemd/system/multi-user.target.wants/getty.target

# Requirements for systemd in Docker
VOLUME ["/sys/fs/cgroup"]
CMD ["/lib/systemd/systemd"]
