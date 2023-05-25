#!/bin/bash

# Initialize options array
options=("NVIDIA Drivers" "TabletPC" "Wine" "Waydroid" "Linux-Xanmod-Anbox" "Content Tools" "Coding Tools" "Steam + Minecraft" "Discord" "Additional Games Support" "DE Games Suite")
status=("off" "off" "off" "off" "off" "off" "off" "off" "off" "off" "off")
selections=()

# Define function to toggle option status
toggle_option() {
  local option_index=$((option-1))
  if [ "${status[$option_index]}" == "off" ]; then
    status[$option_index]="on"
    selections+=("$option")
  else
    status[$option_index]="off"
    selections=( $(echo "${selections[@]}" | tr ' ' '\n' | grep -v "$option" | tr '\n' ' ') )
  fi
}

# Loop to display menu and prompt for input
while true; do
  clear
  echo "Select options using numbers (1-11):"
  echo "----------------------------------"
  for i in "${!options[@]}"; do
    echo "$((i+1))) ${options[i]}: ${status[i]}"
  done
  echo "----------------------------------"
  echo "12) Done"
  read -p "Enter option number: " option

  if [ "$option" -eq "12" ]; then
    break
  fi

  valid_input="0"
  for i in "${!options[@]}"; do
    if [ "$option" -eq "$((i+1))" ]; then
      toggle_option
      valid_input="1"
      break
    fi
  done

  if [ "$valid_input" -eq "0" ]; then
    echo "Invalid option: $option"
  fi
done

# Display final option status
echo "Selected options: ${selections[@]}"

# Prompt the user to enter a number
echo "Would you like a delay between installs? (Enter the number in seconds or press enter to skip.)"
# Read the user input and store it in the variable 'wait'
read wait
wait=${wait:-0}
if ! [[ "$wait" =~ ^[0-9]+$ ]]; then
  wait=0
fi

#Remove intel_pstate=no_hwo from Kernel Parameters
    for file in /boot/loader/entries/*.conf; do
      if [[ "$file" != *"fallback.conf" ]]; then
      sudo sed -i '/options/s/intel_pstate=no_hwp\s*//' $file
      echo "Removed intel_pstate parameter."
      fi
    done

#Enable multilib repo
sudo sed -i 's/^#\[multilib\]/\[multilib\]/' /etc/pacman.conf
echo "Enabled Multilib Repo!"
sleep $wait

#Install yay package manager
sudo pacman -Syu --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si
echo "Installed and enabled YAY AUR helper!"
sleep $wait

# Pacman installations
sudo pacman -Sy --needed flatpak powerdevil power-profiles-daemon ntfs-3g bluez bluez-utils cups cups-pdf lzip sqlite spectacle kdeconnect partitionmanager bleachbit kwallet-pam kwalletmanager noto-fonts-cjk noto-fonts-emoji
echo "Installed base pacman packages!"
sleep $wait

#Enable services
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now power-profiles-daemon.service
sudo systemctl enable --now cups.service
echo "Enabled system services."
sleep $wait

#Flatpak setup and installations
flatpak update && flatpak upgrade
sudo flatpak override --system --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtkrc-2.0:ro --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtkrc:ro
flatpak --user override --filesystem=/home/$USER/.icons/:ro
flatpak --user override --filesystem=/usr/share/icons/:ro
flatpak --user override --filesystem=~/.local/share/fonts:ro
flatpak install --noninteractive org.gtk.Gtk3theme.Breeze org.mozilla.firefox org.mozilla.Thunderbird org.videolan.VLC org.gnome.eog com.github.tchx84.Flatseal org.kde.kamoso org.kde.okular org.kde.filelight org.kde.isoimagewriter org.libreoffice.LibreOffice org.kde.kolourpaint com.github.k4zmu2a.spacecadetpinball org.kde.kmines
echo "Intalled flatpak and base flatpak applications!"
sleep $wait

# Custom Firefox Install & Dolphin settings
sudo cp -rf /run/media/$USER/2GB/org.mozilla.firefox /home/$USER/.var/app/org.mozilla.firefox/
sudo cp -rf /run/media/$USER/2GB/share /home/$USER/.local/share
echo "Applied optimized Firefox and Dolphin settings."
sleep $wait

#Yay installaitions
yay -Sy --needed sddm-git ttf-ms-win11-auto game-devices-udev ttf-ancient-fonts ttf-arabeyes-fonts ttf-freebanglafont ttf-ubraille ttf-paratype otf-gfs ttf-sbl-hebrew ttf-indic-otf iran-nastaliq-fonts
echo "Installed base yay applications!"
sleep $wait


#Nvidia Drivers install
  if [ "${status[0]}" == "on" ]; then
  yay -Sy --needed nvidia-beta
  sudo pacman -Sy --needed lib32-nvidia-utils nvidia-utils nvidia-dkms nvidia-settings
    for file in /boot/loader/entries/*.conf; do
      if [[ "$file" != *"fallback.conf" ]]; then
        if ! grep -q "nvidia-drm.modeset=1" "$file"; then
          sudo sed -e '/^options / s/$/ nvidia-drm.modeset=1/' -i "$file"
          echo "Successfully updated $file"
          sleep $wait
        else
          echo "nvidia-drm.modeset=1 is already present in $file"
          sleep $wait
        fi
      fi
    done
    if ! grep -q "nvidia \| nvidia_modeset \| nvidia_uvm \| nvidia_drm" /etc/mkinitcpio.conf; then
      sudo sed -i '/HOOKS/s/kms\s*//' /etc/mkinitcpio.conf
      sudo sed -i '/HOOKS/s/$/ nvidia nvidia_modeset nvidia_uvm nvidia_drm/' /etc/mkinitcpio.conf
      echo "Successfully updated /etc/mkinitcpio.conf"
      sleep $wait
    else
      sudo sed -i '/HOOKS/s/kms\s*//' /etc/mkinitcpio.conf
      echo "NVIDIA modules are already included in /etc/mkinitcpio.conf"
      sleep $wait
    fi
    sudo mkinitcpio -P
    sudo pacman -Sy --needed xorg-xwayland libxcb egl-wayland
    # Define the text to be written to the file
    hook_text="[Trigger]
    Operation=Install
    Operation=Upgrade
    Operation=Remove
    Type=Package
    Target=nvidia
    # Change the kernel part above and in the Exec line if a different kernel is used

    [Action]
    Description=Update NVIDIA module in initcpio
    Depends=mkinitcpio
    When=PostTransaction
    NeedsTargets
    Exec=/bin/sh -c 'while read -r trg; do case \$trg in $kernel) exit 0; esac; done; /usr/bin/mkinitcpio -P'"
    # Get the current kernel string
    if [ "${status[4]}" == "on" ]; then
    kernel="linux-xanmod-anbox"
  else
    kernel=$(uname -r | awk -F '-' '{sub(/[0-9]+$/, "", $2); print $2}')
  fi
    # Replace the kernel string in the hook_text variable
    hook_text="${hook_text/\[Trigger\]\nOperation=Install\nOperation=Upgrade\nOperation=Remove\nType=Package\nTarget=nvidia\n/\
    [Trigger]\nOperation=Install\nOperation=Upgrade\nOperation=Remove\nType=Package\nTarget=$kernel\n}"
    # Create the directory if it doesn't exist
    sudo mkdir -p /etc/pacman.d/hooks
    # Write the text to the file, overwriting it if it already exists
    echo "$hook_text" | sudo tee /etc/pacman.d/hooks/nvidia.hook >/dev/null 2>&1
    echo "Created /etc/pacman.d/hooks/nvidia.hook"
    echo "Installed NVIDIA Drivers sucessfully!"
    sleep $wait
  else
    echo "Skipped NVIDIA Driver installation."
  fi

#TabletPC Install
  if [ "${status[1]}" == "on" ]; then
    sudo pacman -Sy --needed iio-sensor-proxy maliit-keyboard
    yay -Sy --needed kded-rotation-git
    echo "Installed TabletPC Drivers!"
    sleep $wait
  else
    echo "Skipping TabletPC Drivers."
    sleep $wait
  fi

#Wine Install
  if [ "${status[2]}" == "on" ]; then
      sudo pacman -Sy --needed wine
      flatpak install flathub com.usebottles.bottles
      echo "Installed Wine!"
      sleep $wait
  else
    echo "Skipping Wine installation."
    sleep $wait
  fi

#Waydroid setup
  if [ "${status[3]}" == "on" ]; then
      yay -S waydroid
      sudo waydroid init
      git clone https://github.com/casualsnek/waydroid_script
      cd waydroid_script
      sudo pacman -Sy python3 python-pip
      sudo pip install pyclip
      sudo python3 -m pip install -r requirements.txt
      sudo python3 main.py -m -l -w
      sudo systemctl enable waydroid-container.service
      sudo systemctl start waydroid-container.service
    echo "Installed Waydroid!"
    sleep $wait
  else
    echo "Skipping Waydroid installation."
    sleep $wait
  fi

#Content Tool Install
  if [ "${status[5]}" == "on" ]; then
    flatpak install flathub --noninteractive com.obsproject.Studio org.gimp.GIMP org.kde.kdenlive org.kde.krita org.inkscape.Inkscape org.tenacityaudio.Tenacity
    echo "Installed Content Tools!"
    sleep $wait
  else
    echo "Skipping Content Tools"
    sleep $wait
  fi

#Coding Tool Install
  if [ "${status[6]}" == "on" ]; then
    sudo pacman -Sy --needed git android-tools
    flatpak install flathub --noninteractive com.vscodium.codium com.google.AndroidStudio in.srev.guiscrcpy
    echo "Installed Coding Tools!"
    sleep $wait
  else
    echo "Skipped Coding Tools Install."
    sleep $wait
  fi

#Steam Install
  if [ "${status[7]}" == "on" ]; then
      flatpak install flatub --noninteractive org.prismlauncher.PrismLauncher com.valvesoftware.Steam io.github.philipk.boilr
      echo "Installed Steam and Minecraft!"
      sleep $wait
    else
      echo "Skipping Steam and Minecraft."
      sleep $wait
  fi

#Discord installation
  if [ "${status[8]}" == "on" ]; then
      flatpak  install flathub --noninteractive com.discordapp.Discord de.shorsh.discord-screenaudio
      sh -c "$(curl -sS https://raw.githubusercontent.com/Vendicated/VencordInstaller/main/install.sh)"
      echo "Installed Discord!"
      sleep $wait
    else
      echo "Skipping Discord installation."
      sleep $wait
  fi

#Additional Games
  if [ "${status[9]}" == "on" ]; then
    flatpak install flathub --noninteractive net.lutris.Lutris com.heroicgameslauncher.hgl com.stepmania.StepMania sh.ppy.osu org.libretro.RetroArch io.github.antimicrox.antimicrox com.shatteredpixel.shatteredpixeldungeon org.srb2.SRB2 io.itch.itch
    sudo flatpak override net.lutris.Lutris --filesystem=$HOME
    echo "Installed Additional Games Support!"
    sleep $wait
  else
    echo "Skipped Additional Games Support."
    sleep $wait
  fi

#DE Games Suite
  if [ "${status[10]}" == "on" ]; then
    flatpak install flathub --noninteractive org.kde.bomber org.kde.granatier org.kde.kapman org.kde.kblocks org.kde.kbounce org.kde.kbreakout org.kde.kgoldrunner org.kde.kolf org.kde.kollision org.kde.ksnakeduel org.kde.bovo org.kde.kblackbox org.kde.fourinline org.kde.kigo org.kde.kiriki org.kde.kmahjongg org.kde.knights org.kde.kreversi org.kde.ksquares org.kde.kpat org.kde.lskat org.kde.blinken org.kde.gcompris org.kde.kanagram org.kde.khangman org.kde.kdiamond org.kde.ksudoku org.kde.kubrik org.kde.palapeli org.kde.picmi org.kde.katomic org.kde.killbots org.kde.kjumpingcube org.kde.klickety org.kde.knetwalk org.kde.klines org.kde.konquest org.kde.ksame org.kde.ksirk org.kde.knavalbattle party.supertux.supertuxparty org.supertuxproject.SuperTux net.supertuxkart.SuperTuxKart io.github.retux_game.retux io.github.dstudo.TuxPlanetSpeedrunAnyPercent
    echo "Installed DE Games Suite!"
    sleep $wait
  else
    echo "Skipping DE Games Suite."
    sleep $wait
  fi

#Linux-Xanmod-Anbox kernel setup
  if [ "${status[4]}" == "on" ]; then
  yay -Sy --needed linux-xanmod-anbox
  for file in /boot/loader/entries/*.conf; do
    if [[ "$file" != *"fallback.conf" ]]; then
      if ! grep -q "psi=1" "$file"; then
        sudo sed -e '/^options / s/$/ psi=1/' -i "$file"
        echo "Successfully updated $file"
        sleep $wait
      else
        echo "psi=1 is already present in $file"
        sleep $wait
      fi
    fi
  done
    # Set input and output files
    kernel_ver=$(uname -r | awk -F '-' '{sub(/[0-9]+$/, "", $2); print $2}')
    input_file="/boot/loader/entries/linux-$kernel_ver.conf"
    output_file=/boot/loader/entries/linux-xanmod-anbox.conf
    # Replace "linux-$kernel_ver" with "linux-xanmod-anbox" in the input file and write to
    # the output file
    sudo sed "s/linux-$kernel_ver/linux-xanmod-anbox/g" "$input_file" > "$output_file"

    echo "Install Linux-Xanmod-Anbox successfully!"
    sleep $wait
  else
    echo "Skipped Linux-Xanmod-Anbox."
    sleep $wait
  fi

echo "Installation complete!"
flatpak run org.mozilla.firefox https://addons.mozilla.org/en-US/firefox/collections/17507785/mobile/
read -n 1 -s -r -p "Press any key to exit..."
