# dotfiles
Home directory replication

Steps to setup:
1. install gnu stow like `brew install stow`
2. install a nerdfont https://www.nerdfonts.com/font-downloads
3. install oh-my-posh like `brew install oh-my-posh`
4. clone repo and submodules to ~/dotfiles
5. cd ~/dotfiles; stow .

# backed up zeus config

* etc-zfs-vdev\_id.conf -> /etc/zfs/vdev\_id.conf
* etc\_systemd\_system\_set-scterc@.service -> /etc/systemd/system/set-scterc@.service
* etc\_udev\_rules.d\_60-zfs-scterc.rules -> /etc/udev/rules.d/60-zfs-scterc.rules
