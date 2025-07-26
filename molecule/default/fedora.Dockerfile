# Dockerfile for fedora:latest
# SPDX-License-Identifier: MIT
#
# Built from the following sources:
# - https://github.com/geerlingguy/docker-fedora42-ansible/blob/master/Dockerfile
# - https://hub.docker.com/r/rockylinux/rockylinux
# - https://ansible.readthedocs.io/projects/molecule/guides/systemd-container/
#
# Dockerfile reference: https://docs.docker.com/reference/dockerfile/
FROM fedora:latest
ENV container docker

RUN dnf -y update && dnf clean all

# Enable systemd.
RUN dnf -y install systemd && dnf clean all && \
    (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;

# Install packages
RUN dnf -y install \
    python3-pip \
    sudo \
    which \
    python3-libdnf5 \
    && dnf clean all

# Install Ansible via Pip.
RUN python3 -m pip install --user ansible

# Disable requiretty.
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/'  /etc/sudoers

# Install Ansible inventory file.
RUN mkdir -p /etc/ansible
RUN echo -e "[local]\nlocalhost ansible_connection=local" > /etc/ansible/hosts

# Required for systemd in Docker
VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]
