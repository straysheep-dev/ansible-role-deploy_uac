deploy_uac
=========

![ansible-lint workflow](https://github.com/straysheep-dev/ansible-role-deploy_uac/actions/workflows/ansible-lint.yml/badge.svg) ![shellcheck workflow](https://github.com/straysheep-dev/ansible-role-deploy_uac/actions/workflows/shellcheck.yml/badge.svg)

Drops the latest release of [UAC (Unix-like Artifacts Collector)](https://github.com/tclahr/uac) and any precompiled binaries found in this role's `files/` folder, across an inventory to gather and retrieve evidence.

If you create precompiled binaries, make sure [the required directory structure](https://tclahr.github.io/uac-docs/#using-your-binary-files) exists under `files/` like this:

```bash
deploy_uac/files/linux/x86_64/chkrootkit
deploy_uac/files/aix/powerpc/lsof
deploy_uac/files/android/aarch64/netstat
```

The options available as variables can be useful during a live response scenario to customize how UAC is deployed and what it collects.

- Choose a profile to use
- Provide a list of artifacts to collect
- Specify the paths to download and run UAC on remote hosts

Mostly this allows you to collect evidence from an entire inventory at scale. The variables create opportunities to vary and adust how UAC is deployed in the event an adversary has direct access to an endpoint and actively tries to interfere with `uac`.

With that in mind, `ansible.builtin.stat` is used to record the path (filename), checksum, mtime, mimetype, and inode of the resulting `.log` and `.tar.gz` files as soon as they're written to disk, and again once you retrieve them using `ansible.builtin.fetch`.

If there's a mismatch in SHA256SUMS, the play for that host fails. The idea is this makes the effort to prevent modification of the archives themselves, however malicious data can still be present *within* the `.tar.gz` archive.

> [!IMPORTANT]
> *In my testing, I was not able to inject a random file into the archive by writing it to the `uac-data.tmp` folder as it's gathering evidence on a system. I was however able to replace one of the `.txt` files with an ELF binary. **Use caution when reviewing retrieved evidence**.*

Requirements
------------

The remote nodes must be a Unix-like OS. UAC supports the following systems:

> AIX, Android, ESXi, FreeBSD, Linux, macOS, NetBSD, NetScaler, OpenBSD and Solaris

**This role has been tested on:**

- Linux (Debian/Ubuntu, Fedora)
- FreeBSD, pfSense

**Older Systems**

The latest versions of Ansible will not execute on systems with older versions of `python3` installed. You will see an error similar to this, where it isn't even able to print the required version information:

```bash
fatal: [10.10.10.55]: FAILED! => {"ansible_facts": {}, "changed": false, "failed_modules": {"ansible.legacy.setup": {"ansible_facts": {"discovered_interpreter_python": "/usr/bin/python3"}, "exception": "Traceback (most recent call last):

<SNIP>

  File \"/tmp/ansible_ansible.legacy.setup_payload_zlebszdb/ansible_ansible.legacy.setup_payload.zip/ansible/module_utils/basic.py\", line 17
    msg=f\"ansible-core requires a minimum of Python version {'.'.join(map(str, _PY_MIN))}. Current version: {''.join(sys.version.splitlines())}\",

```

> [!TIP]
> The versions found to be the most successful for these use cases are Ansible 2.13.0 or above.

**This role has been tested using:**

- ansible-playbook [core 2.17.12]
- ansible-playbook [core 2.13.0]

**Installing Older Versions of Ansible**

See: [Ansible Community Changelogs](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-community-changelogs)

Using [pipx you can install multiple versions of packages side by side](https://github.com/pypa/pipx/pull/445). This is useful when you want the latest version of a package, and also a specific version of a package on the same system for testing.

To install all of the `ansible-` tools, [you need to specify `ansible-core`](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#pipx-install).

```bash
version_number="1.2.3"
package_name='ansible-core' # or ansible-core
pipx install --suffix=_"$version_number" "$package_name"=="$version_number"
```

Call the version-pinned installation using the suffix:

```bash
ansible-playbook_1.2.3 --version  # If installing ansible-core==1.2.3
ansible-lint_1.2.3 --version # If installing ansible-lint==1.2.3
```

Remove any versions you may have installed through `pipx` by following the steps above for testing:

```bash
version_number="2.12.10"
package_name='ansible-core' # or ansible-core
pipx uninstall "$package_name"_"$version_number"
```

Role Variables
--------------

Define these in your inventory file, per-host, or per-group.

Modify how UAC is deployed:

- `uac_retrieve_evidence: true` Option to not retrieve evidence locally, and leave it on the remote machine, mainly for debugging
- `uac_cleanup: false` Should be changed to true in a continuous live response scenario, so you have the best chance of using trustworthy tools and not being seen
- `uac_download_folder: "/tmp/uac.tmp"` Modify this to change where UAC drops
- `uac_profile: "-p ir_triage"` Default is `ir_triage`, can also be `full` or `offline`

Use these for a list of specific artifacts, otherwise it will gather everything `-p <PROFILE>` is configured to collect:

- `uac_use_artifact_list: false` Set to `true` to use the artifacts listed
- `uac_artifacts_list:` The list of artifacts (see the example inventory file below)

These control where and how the evidence is written on the remote node. The `-o` option has not yet been added to the latest release:

- `uac_outfile_name: "uac-{{ ansible_hostname }}-{{ ansible_system | lower }}-{{ ansible_date_time.iso8601_basic_short }}"`
- `uac_outfile_arg: "-o {{ uac_outfile_name }}"` Uses the Ansible variables above, to access the filename as a variable
- `uac_outfile_arg: ""` Leave this variable empty to use the default filename of `uac-%hostname%-%os%-%timestamp%`
- `uac_outfolder: "{{ uac_download_folder }}/results"` Where to write the resulting evidence archive, should be its own folder

This sets the path where all of your UAC evidence will be stored back on your local machine:

- `uac_evidence_folder: "/home/{{ ansible_facts['env']['USER'] }}/uac-evidence"` Local folder where evidence archives are retrieved and stored

Example inventory file (YAML works better for defining `uac_artifacts_list`):

```yml
tester_nodes:
  hosts:
    192.168.0.20:
      ansible_port: 22
      ansible_user: root

  vars:
    is_tester: "true"
    is_manager: "true"

target_nodes:
  hosts:
    10.10.10.71:
      ansible_port: 22
      ansible_user: root
    10.10.10.72:
      ansible_port: 22
      ansible_user: root
    10.10.10.73:
      ansible_port: 22
      ansible_user: root

  vars:
    is_target: "true"
    is_managed: "true"
    # deploy_uac options
    uac_cleanup: "false"
    uac_download_folder: "/dev/shm/uac.tmp"
    #uac_profile: "-p ir_triage"
    uac_use_artifact_list: "true"
    uac_artifacts_list:
      - live_response/system/ebpf.yaml
      - live_response/system/kernel_modules.yaml
      - live_response/system/modinfo.yaml
      - live_response/system/lsmod.yaml
      - live_response/system/hidden_files.yaml
      - live_response/system/sys_modules.yaml
      - live_response/hardware/dmesg.yaml
      - live_response/process/strings_running_processes.yaml
      - live_response/process/procstat.yaml
```

Dependencies
------------

None, uac just needs a shell to run.

Example Playbook
----------------

Using the example inventory file (above), you could create the following playbook file:

```yml
- name: "Default Playbook"
  hosts: all
    #target_nodes
    #tester_nodes
  roles:
    - role: "deploy_uac"
```

Load credentials from an ansible-vault and run the playbook with:

```bash
echo "Enter Vault Password"; read -r -s vault_pass; export ANSIBLE_VAULT_PASSWORD=$vault_pass
# [type vault password here, then enter]
ansible-playbook -i <inventory> -e "@~/vault.yml" --vault-pass-file <(cat <<<$ANSIBLE_VAULT_PASSWORD) -v ./playbook.yml
```

License
-------

- [MIT](./LICENSE): This role is released under the MIT license.
- [Apache-2.0](https://github.com/tclahr/uac/blob/main/LICENSE): [uac](https://github.com/tclahr/uac) itself is available under the Apache-2.0 license.

Author Information
------------------

https://github.com/straysheep-dev/ansible-configs
