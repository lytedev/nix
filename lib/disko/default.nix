{ nixpkgs-unstable, ... }:
let
  # TODO: This file needs some serious cleaning up.
  lib = nixpkgs-unstable.lib;
  inherit (lib.attrsets) mapAttrs' filterAttrs;
  ESP =
    inputs@{
      size ? "4G",
      label ? "ESP",
      name ? "ESP",
    }:
    {
      priority = 1;
      start = "1M";
      label = label;
      name = name;
      end = size;
      type = "EF00";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [
          "umask=0077"
        ];
      };
    }
    // inputs;
in
rec {
  standardWithHibernateSwap =
    {
      esp ? {
        label = "ESP";
        size = "4G";
        name = "ESP";
      },
      rootfsName ? "/rootfs",
      homeName ? "/home",
      disk,
      swapSize,
      ...
    }:
    {
      /*
        this is my standard partitioning scheme for my machines which probably want hibernation capabilities
        a UEFI-compatible boot partition
        it includes an LUKS-encrypted btrfs volume
        a swap partition big enough to dump all the machine's RAM into
      */

      disko.devices = {
        disk = {
          primary = {
            type = "disk";
            device = disk;
            content = {
              type = "gpt";
              partitions = {
                ESP = ESP esp;
                swap = {
                  size = swapSize;
                  content = {
                    type = "swap";
                    discardPolicy = "both";
                    resumeDevice = true; # resume from hiberation from this device
                  };
                };
                luks = {
                  size = "100%";
                  content = {
                    type = "luks";
                    name = "crypted";
                    # if you want to use the key for interactive login be sure there is no trailing newline
                    # for example use `echo -n "password" > /tmp/secret.key`
                    keyFile = "/tmp/secret.key"; # Interactive
                    # settings.keyFile = "/tmp/password.key";
                    # additionalKeyFiles = ["/tmp/additionalSecret.key"];
                    content = {
                      type = "btrfs";
                      extraArgs = [ "-f" ];
                      subvolumes = {
                        ${rootfsName} = {
                          mountpoint = "/";
                          mountOptions = [ "compress=zstd" ];
                        };
                        ${homeName} = {
                          mountpoint = "/home";
                          mountOptions = [ "compress=zstd" ];
                        };
                        "/nix" = {
                          mountpoint = "/nix";
                          mountOptions = [
                            "compress=zstd"
                            "noatime"
                          ];
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

  foxtrot = standardWithHibernateSwap {
    disk = "nvme0n1";
    swapSize = "32G";
    rootfsName = "/nixos-rootfs";
    homeName = "/nixos-home";
    esp = {
      label = "disk-primary-ESP";
      name = "disk-primary-ESP";
    };
  };

  standard =
    {
      esp ? {
        label = "ESP";
        size = "4G";
        name = "ESP";
      },
      disk,
      ...
    }:
    {
      # this is my standard partitioning scheme for my machines: an LUKS-encrypted
      # btrfs volume
      disko.devices = {
        disk = {
          primary = {
            type = "disk";
            device = disk;
            content = {
              type = "gpt";
              partitions = {
                ESP = ESP esp;
                luks = {
                  size = "100%";
                  content = {
                    type = "luks";
                    name = "crypted";
                    # if you want to use the key for interactive login be sure there is no trailing newline
                    # for example use `echo -n "password" > /tmp/secret.key`
                    keyFile = "/tmp/secret.key"; # Interactive
                    # settings.keyFile = "/tmp/password.key";
                    # additionalKeyFiles = ["/tmp/additionalSecret.key"];
                    content = {
                      type = "btrfs";
                      extraArgs = [ "-f" ];
                      subvolumes = {
                        "/root" = {
                          mountpoint = "/";
                          mountOptions = [ "compress=zstd" ];
                        };
                        "/home" = {
                          mountpoint = "/home";
                          mountOptions = [ "compress=zstd" ];
                        };
                        "/nix" = {
                          mountpoint = "/nix";
                          mountOptions = [
                            "compress=zstd"
                            "noatime"
                          ];
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

  thablet = standard {
    disk = "nvme0n1";
    esp = {
      label = "EFI";
      size = "4G";
      name = "EFI";
    };
  };

  unencrypted =
    { disk, ... }:
    {
      disko.devices = {
        disk = {
          primary = {
            type = "disk";
            device = disk;
            content = {
              type = "gpt";
              partitions = {
                ESP = ESP { size = "5G"; };
                root = {
                  size = "100%";
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];
                    mountpoint = "/partition-root";
                    subvolumes = {
                      "/rootfs" = {
                        mountpoint = "/";
                        mountOptions = [ "compress=zstd" ];
                      };
                      "/home" = {
                        mountpoint = "/home";
                        mountOptions = [ "compress=zstd" ];
                      };
                      "/nix" = {
                        mountpoint = "/nix";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

  beefcake =
    let
      zpools = {
        zroot = {
          /*
            TODO: at the time of writing, disko does not support draid6
            so I'm building/managing the array manually for the time being
            the root pool is just a single disk right now
          */
          name = "zroot";
          config = {
            type = "zpool";
            # mode = "draid6";
            rootFsOptions = {
              compression = "zstd";
              "com.sun:auto-snapshot" = "false";
            };
            mountpoint = "/";
            postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot@blank$' || zfs snapshot zroot@blank";

            datasets = {
              zfs_fs = {
                type = "zfs_fs";
                mountpoint = "/zfs_fs";
                options."com.sun:auto-snapshot" = "true";
              };
              zfs_unmounted_fs = {
                type = "zfs_fs";
                options.mountpoint = "none";
              };
              zfs_legacy_fs = {
                type = "zfs_fs";
                options.mountpoint = "legacy";
                mountpoint = "/zfs_legacy_fs";
              };
              zfs_testvolume = {
                type = "zfs_volume";
                size = "10M";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/ext4onzfs";
                };
              };
              encrypted = {
                type = "zfs_fs";
                options = {
                  mountpoint = "none";
                  encryption = "aes-256-gcm";
                  keyformat = "passphrase";
                  keylocation = "file:///tmp/secret.key";
                };
                # use this to read the key during boot
                /*
                  postCreateHook = ''
                    zfs set keylocation="prompt" "zroot/$name";
                  '';
                */
              };
              "encrypted/test" = {
                type = "zfs_fs";
                mountpoint = "/zfs_crypted";
              };
            };
          };
        };
        zstorage = {
          /*
            PARITY_COUNT=3 NUM_DRIVES=8 HOT_SPARES=2 sudo -E zpool create -f -O mountpoint=none -O compression=on -O xattr=sa -O acltype=posixacl -o ashift=12 -O atime=off -O recordsize=64K zstorage draid{$PARITY_COUNT}:{$NUM_DRIVES}c:{$HOT_SPARES}s /dev/disk/by-id/scsi-35000039548cb637c /dev/disk/by-id/scsi-35000039548cb7c8c /dev/disk/by-id/scsi-35000039548cb85c8 /dev/disk/by-id/scsi-35000039548d9b504 /dev/disk/by-id/scsi-35000039548da2b08 /dev/disk/by-id/scsi-35000039548dad2fc /dev/disk/by-id/scsi-350000399384be921 /dev/disk/by-id/scsi-35000039548db096c
            sudo zfs create -o mountpoint=legacy zstorage/nix
            sudo zfs create -o canmount=on -o mountpoint=/storage zstorage/storage
          */
          name = "zstorage";
          config = { };
        };
      };
      diskClass = {
        storage = {
          type = "zfs";
          pool = zpools.zroot.name;
        };
        boot = {
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = zpools.zroot.name;
                };
              };
            };
          };
        };
      };
      bootDisks = {
        "/dev/sdi" = {
          name = "i";
          enable = true;
        };
        "/dev/sdj" = {
          name = "j";
          enable = true;
        }; # TODO: join current boot drive to new boot pool
      };
      storageDisks = {
        "/dev/sda" = {
          enable = true;
          name = "a";
        };
        "/dev/sdb" = {
          enable = true;
          name = "b";
        };
        "/dev/sdc" = {
          enable = true;
          name = "c";
        };
        "/dev/sdd" = {
          enable = true;
          name = "d";
        };

        # TODO: start small
        "/dev/sde" = {
          enable = false;
          name = "e";
        };
        "/dev/sdf" = {
          enable = false;
          name = "f";
        };
        "/dev/sdg" = {
          enable = false;
          name = "g";
        };
        "/dev/sdh" = {
          enable = false;
          name = "h";
        };

        # gap for two boot drives

        "/dev/sdk" = {
          enable = false;
          name = "k";
        };
        "/dev/sdl" = {
          enable = false;
          name = "l";
        };
        "/dev/sdm" = {
          enable = false;
          name = "m";
        };
        "/dev/sdn" = {
          # TODO: this is my holding cell for random stuff right now
          enable = false;
          name = "n";
        };
      };

      diskoBoot = mapAttrs' (
        device:
        { name, ... }:
        {
          name = "boot-${name}";
          value = {
            inherit device;
            type = "disk";
            content = diskClass.boot.content;
          };
        }
      ) (filterAttrs (_: { enable, ... }: enable) bootDisks);

      diskoStorage = mapAttrs' (
        device:
        { name, ... }:
        {
          name = "storage-${name}";
          value = {
            inherit device;
            type = "disk";
            content = diskClass.storage.content;
          };
        }
      ) (filterAttrs (_: { enable, ... }: enable) storageDisks);
    in
    {
      disko.devices = {
        disk = diskoBoot // diskoStorage;
        zpool = {
          zroot = zpools.zroot.config;
        };
      };
    };

  legacy =
    { disks, ... }:
    {
      disko.devices = {
        disk = {
          primary = {
            device = builtins.elemAt disks 0;
            type = "disk";
            content = {
              type = "table";
              format = "gpt";
              partitions = [
                {
                  label = "EFI";
                  name = "ESP";
                  size = "512M";
                  bootable = true;
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                  };
                }
                {
                  name = "root";
                  start = "500M";
                  end = "100%";
                  part-type = "primary";
                  bootable = true;
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/";
                  };
                }
              ];
            };
          };
        };
      };
    };
}
