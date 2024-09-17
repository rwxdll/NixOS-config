{
  inputs,
  lib,
  ...
}:

{
  imports = [
    inputs.disko.nixosModules.default
  ];

  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_23376A441301";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              name = "ESP";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              name = "root";
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
      secondary = {
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_23376B453408";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            data = {
              name = "data";
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                mountpoint = "/data/D";
                mountOptions = [ "noatime" ];
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                };
                "/persist" = {
                  mountOptions = [ "subvol=persist" "noatime" ];
                  mountpoint = "/persist";
                };
                "/nix" = {
                  mountOptions = [ "subvol=nix" "noatime" ];
                  mountpoint = "/nix";
                };
              };
            };
          };
        };
      };
    };
  };

  boot.initrd.systemd.services.rollback = {
    description = "Rollback BTRFS root subvolume to a pristine state";
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    wantedBy = [ "initrd.target" ];
    requires = [ "dev-disk-by\\x2did-nvme\\x2dWD_BLACK_SN850X_2000GB_23376A441301.device"];
    after = [ "dev-disk-by\\x2did-nvme\\x2dWD_BLACK_SN850X_2000GB_23376A441301.device" ];
    before = [ "sysroot.mount" ];

    script = ''
      echo "Starting rollback service..."

      vgchange -ay pool
      mkdir -p /btrfs_tmp
      mount /dev/pool/root /btrfs_tmp

      if [[ -e /btrfs_tmp/root ]]; then
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          btrfs subvolume delete "$1"
      }

      for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
          delete_subvolume_recursively "$i"
      done

      btrfs subvolume create /btrfs_tmp/root
      umount /btrfs_tmp
    '';
  };

  fileSystems."/persist".neededForBoot = true;
}
