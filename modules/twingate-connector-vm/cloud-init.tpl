#cloud-config

package_update: true
package_upgrade: ${enable_auto_updates}

packages:
  - docker.io
  - curl
  - jq
%{ if enable_auto_updates ~}
  - unattended-upgrades
%{ endif ~}

write_files:
  - path: /etc/twingate/connector.env
    permissions: '0600'
    content: |
      TWINGATE_NETWORK=${twingate_network}
      TWINGATE_ACCESS_TOKEN=${access_token}
      TWINGATE_REFRESH_TOKEN=${refresh_token}

  - path: /etc/systemd/system/twingate-connector.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Twingate Connector
      Requires=docker.service
      After=docker.service

      [Service]
      Type=simple
      Restart=always
      RestartSec=10
      EnvironmentFile=/etc/twingate/connector.env
      ExecStartPre=-/usr/bin/docker stop twingate-connector
      ExecStartPre=-/usr/bin/docker rm twingate-connector
      ExecStartPre=/usr/bin/docker pull ${connector_image}
      ExecStart=/usr/bin/docker run --rm --name twingate-connector \
        -e TWINGATE_NETWORK \
        -e TWINGATE_ACCESS_TOKEN \
        -e TWINGATE_REFRESH_TOKEN \
        ${connector_image}
      ExecStop=/usr/bin/docker stop twingate-connector

      [Install]
      WantedBy=multi-user.target

%{ if enable_auto_updates ~}
  - path: /etc/apt/apt.conf.d/20auto-upgrades
    permissions: '0644'
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
      APT::Periodic::AutocleanInterval "7";

  - path: /etc/apt/apt.conf.d/50unattended-upgrades
    permissions: '0644'
    content: |
      Unattended-Upgrade::Allowed-Origins {
        "$${distro_id}:$${distro_codename}";
        "$${distro_id}:$${distro_codename}-security";
        "$${distro_id}ESMApps:$${distro_codename}-apps-security";
        "$${distro_id}ESM:$${distro_codename}-infra-security";
      };
      Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
      Unattended-Upgrade::Remove-Unused-Dependencies "true";
      Unattended-Upgrade::Automatic-Reboot "true";
      Unattended-Upgrade::Automatic-Reboot-Time "03:00";
%{ endif ~}

runcmd:
  - mkdir -p /etc/twingate
  - systemctl daemon-reload
  - systemctl enable docker
  - systemctl start docker
  - systemctl enable twingate-connector
  - systemctl start twingate-connector
