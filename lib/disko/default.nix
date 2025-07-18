{ nixpkgs-unstable, ... }:
# TODO: This file needs some serious cleaning up.
let
  inherit (lib.attrsets) mapAttrs' filterAttrs;
  lib = nixpkgs-unstable.lib;
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
  # EFI = Extensible Firmware Interface
  # UEFI = Unified EFI
  # ESP = EFI System Partition
  zfsEncryptedUser =
    {
      # generally the hostname of the machine physically containing the disk
      # plus some unique identifier
      diskName,

      # the path to the disk device, usually /dev/nvme0n1 or /dev/sda
      fullDiskDevicePath,

      espLabel ? "ESP",
      espSize ? "4G",
      espName ? espLabel,
      poolName ? "${diskName}pool",

      rootDatasetName ? "nixosroot",
      rootDatasetEncrypt ? true,
      rootDatasetKeyFormat ? "passphrase",
      rootDatasetKeyLocation ? "prompt",
      rootDatasetKeyText ? "",

      userDatasetUsername ? "daniel",
      userDatasetKeyFormat ? "${rootDatasetKeyFormat}",
      userDatasetKeyLocation ? "${rootDatasetKeyLocation}",
      userDatasetKeyText ? "${rootDatasetKeyText}",
    }:
    {
      # TODO: https://unix.stackexchange.com/questions/529047/is-there-a-way-to-have-hibernate-and-encrypted-swap-on-nixos
      # would be nice to:
      # not have to specify a swap partition size so each machine can simply create and reference a swapfile in its own config
      # encrypt the swap file/partition if the root fs is encrypted?
      disko.devices = {
        disk = {
          ${diskName} = {
            type = "disk";
            device = fullDiskDevicePath;
            content = {
              type = "gpt";
              partitions = {
                ESP = ESP {
                  size = espSize;
                  label = espLabel;
                  name = espName;
                };
                zfs = {
                  size = "100%";
                  content = {
                    type = "zfs";
                    pool = poolName;
                  };
                };
              };
            };
          };
        };
        zpool = {
          ${poolName} = {
            # name = poolName;
            type = "zpool";
            # mode = "mirror";

            # Workaround: cannot import 'zroot': I/O error in disko tests
            options.cachefile = "none";

            rootFsOptions = {
              compression = "zstd";
              "com.sun:auto-snapshot" = "false";
            };

            mountpoint = "/";
            # TODO: assert keys are correct length (8-512 bytes I think)
            # TODO: assert that if the location is the same then the key texts must be the same
            # TODO: also must assert the locations are files
            preCreateHook = lib.strings.concatStringsSep ";" [
              (
                if userDatasetKeyText != "" then
                  ''printf "${userDatasetKeyText}" > "${
                    builtins.substring (builtins.stringLength "file://") (builtins.stringLength userDatasetKeyLocation)
                      userDatasetKeyLocation
                  }"''
                else
                  ''echo noop''
              )
              (
                if rootDatasetKeyText != "" then
                  ''printf "${rootDatasetKeyText}" > "${
                    builtins.substring (builtins.stringLength "file://") (builtins.stringLength rootDatasetKeyLocation)
                      rootDatasetKeyLocation
                  }"''
                else
                  ''echo noop''
              )
            ];
            # preCreateHook = "printf yoyoyoyo > /tmp/secret.key";
            postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^${poolName}@blank$' || zfs snapshot ${poolName}@blank";

            datasets = {
              ${rootDatasetName} = {
                type = "zfs_fs";
                options =
                  {
                    "com.sun:auto-snapshot" = "true";
                  }
                  // (
                    if rootDatasetEncrypt then
                      {
                        encryption = "aes-256-gcm";
                        keyformat = rootDatasetKeyFormat;
                        keylocation = rootDatasetKeyLocation;
                      }
                    else
                      { }
                  );
              };

              "${rootDatasetName}/home" = {
                type = "zfs_fs";
                mountpoint = "/home";

                options = {
                  "com.sun:auto-snapshot" = "true";
                };
              };

              "${rootDatasetName}/home/${userDatasetUsername}" = {
                type = "zfs_fs";
                mountpoint = "/home/${userDatasetUsername}";

                options = {
                  "com.sun:auto-snapshot" = "true";
                  encryption = "aes-256-gcm";
                  keyformat = userDatasetKeyFormat;
                  keylocation = userDatasetKeyLocation;
                };
              };
            };
          };
        };
      };
    };

  foxtrotZfs = zfsEncryptedUser {
    fullDiskDevicePath = "/dev/nvme0n1";
    diskName = "foxtrot";
  };

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

  thinker = {
    disko.devices = {
      disk = {
        primary = {
          type = "disk";
          device = "nvme0n1";
          content = {
            type = "gpt";
            partitions = {
              ESP = ESP {
                label = "disk-primary-ESP";
                name = "disk-primary-ESP";
              };
              swap = {
                size = "32G";
                content = {
                  type = "swap";
                  discardPolicy = "both";
                  resumeDevice = true;
                };
              };
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "crypted";
                  keyFile = "/tmp/secret.key";
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];
                    subvolumes = {
                      "/nixos-rootfs" = {
                        mountpoint = "/";
                        mountOptions = [ "compress=zstd" ];
                      };
                      "/nixos-home" = {
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

  babyflip = {
    disko.devices = {
      disk = {
        primary = {
          type = "disk";
          device = "/dev/nvme0n1";
          content = {
            type = "gpt";
            partitions = {
              ESP = ESP {
                label = "disk-primary-ESP";
                name = "disk-primary-ESP";
              };
              swap = {
                size = "8G";
                content = {
                  type = "swap";
                  discardPolicy = "both";
                  resumeDevice = true;
                };
              };
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "crypted";
                  keyFile = "/tmp/secret.key";
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];
                    subvolumes = {
                      "/nixos1-rootfs" = {
                        mountpoint = "/";
                        mountOptions = [ "compress=zstd" ];
                      };
                      "/nixos1-home" = {
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

  foxtrot = {
    disko.devices = {
      disk = {
        primary = {
          type = "disk";
          device = "nvme0n1";
          content = {
            type = "gpt";
            partitions = {
              ESP = ESP {
                label = "disk-primary-ESP";
                name = "disk-primary-ESP";
              };
              # swap = {
              #   size = "4G";
              #   content = {
              #     type = "swap";
              #     discardPolicy = "both";
              #     resumeDevice = false;
              #   };
              # };
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
                      "/nixos-rootfs" = {
                        mountpoint = "/";
                        mountOptions = [ "compress=zstd" ];
                      };
                      "/nixos-home" = {
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
              swap2 = {
                size = "32G";
                content = {
                  type = "swap";
                  discardPolicy = "both";
                  resumeDevice = true; # resume from hiberation from this device
                };
              };
            };
          };
        };
      };
    };
  };

  standardEncrypted =
    {
      disk,
      espSize ? "4G",
      ...
    }:
    standard {
      inherit disk;
      esp = {
        label = "ESP";
        size = espSize;
        name = "ESP";
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
    {
      disk,
      name ? "primary",
      boot-subvolume-size ? "5G",
      ...
    }:
    {
      disko.devices = {
        disk = {
          ${name} = {
            type = "disk";
            device = disk;
            content = {
              type = "gpt";
              partitions = {
                ESP = ESP { size = boot-subvolume-size; };
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
