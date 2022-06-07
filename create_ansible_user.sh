USER="ansible"
SSH_PUBLIC_KEY="ssh-rsa blahblahblah"

adduser $USER --disabled-password --shell /bin/bash --quiet

# create user
mkdir -p "/home/$USER/.ssh/"
echo $SSH_PUBLIC_KEY > "/home/$USER/.ssh/authorized_keys"
chown -R $USER:$USER "/home/$USER/.ssh/"

# give SUDO privs
echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-$USER
