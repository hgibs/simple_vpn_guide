# How to create your own VPN

[Subscription based VPNs aren't as secure as most people think!](https://www.networkworld.com/article/3340342/that-vpn-may-not-be-as-secure-as-you-think.html) The good news is that making your own is easy, and can be cheaper than subscriptions anyway.

We will use wireguard as a VPN tunneling protocol for its wide support, easy setup, and good performance.

# Requirements

#### 1. A DNS name

a large number ".xyz" like "1236581.xyz" is only $1 a year from namecheap, so there's really no excuse. If you need inspiration, a date can be easy to remember, like d-day for example: "06061944.xyz" (although that one is already taken). TLDs with .tk and .ml, for example are free (although these countries require you to regularly use them, and may have some other odd requirements so you get what you pay for). No traffic goes through your DNS provider, so use whomever you want.

#### 2. Basic knowledge on SSH, linux

If you know how to run `sudo apt install` via `ssh` you are fine.

## Step 1 - Choose a cloud provider

You have many options for a VPS provider:

| Cloud Provider | Price | Bandwidth | Pros                            | Cons                                                       |
|----------------|-------|-----------|---------------------------------|------------------------------------------------------------|
| AWS/Azure      | $$$$  | 10+ GB/s  | Customer support, IaC support   | Pay for traffic                                            |
| Hetzner        | $     | 100 MB/s  | Cheap, 20TB traffic for free    | latency (if EU host)                                       |
| Contabo        | $     | 100 MB/s  | Cheap                           | Bad IO performance, poor support                           |
| Oracle         | Free  | 1+ GB/s   | Free forever, 10TB free traffic | It's oracle, ARM architecture, probably won't last forever |
| GCP            | Free  | 1 GB/s    | Free forever, IaC support       | 1GB traffic                                                |


I chose Hetzner for the recommendations and the nearly unlimited bandwidth.
I opted to pay a bit more for a US location which should ease the latency penalties.

## Step 2 - Prep configs

### Step 2A - allow incoming connections
Allow UDP/51820 inbound (and 22 for ssh)
You want to allow all outbound connections for your VPN clients to connect to whatever they want.

## Step 2B - Set up Wireguard

First you need to create a private key for the server.

On your local computer
```
brew install wireguard-tools
mkdir -p ~/.wireguard
wg genkey > ~/.wireguard/serv_priv.key
chmod 700 ~/.wireguard/serv_priv.key
```

# Step 3 - Create server and register

Create your server, I recommend using the smallest instance because wireguard is really lightweight.

Once your server is created, note down the public ip address(es) and register them as `A` (and `AAAA` if you are using IPv6) entries in your dns provider. 'vpn' is a nice subdomain key to use, but use whatever you want.

You'll need to create an ssh key to use ansible in the next step:

```console
$ ssh-keygen -t ed25519 -f ~/.ssh/ansible_ed25519
Generating public/private ed25519 key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /Users/<username>/.ssh/ansible_ed25519
Your public key has been saved in /Users/<username>/.ssh/ansible_ed25519.pub
The key fingerprint is:
SHA256:8emNyejNQzMOdgGVD6I+KP81oYAUekk5HEw6SIlTl3M
The key's randomart image is:
+--[ED25519 256]--+
|.*Bo..   ...     |
|===+o E o o      |
|=.+. o ..o o     |
| + .  .  o...    |
|  . .o  S o.     |
|  . ..o.o==+     |
|   o  .o+==o.    |
|    .  o +o      |
|     .. . o.     |
+----[SHA256]-----+
$ cat ~/.ssh/ansible_ed25519.pub
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOqOe3vd+5vp7gqoGe9eIiXuJ8BocA/cRyxshJYIJFb <username>@<hostname>
```

Then you copy this **public key data** over to the new default user on the server, probably `debian` (i.e. `ssh debian@<ip address>` then `echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOqOe3vd+5vp7gqoGe9eIiXuJ8BocA/cRyxshJYIJFb ansible-key" >> ~/.ssh/authorized_keys`)

Make sure this default user has root permissions. If your default user is `root` then you are good to go (but I encourage you to follow best practices and create an ansible user with no password `sudo` privileges.)
as root:
```console
# adduser ansible
Adding user `ansible' ...
Adding new user `ansible' (1501) with group `ansible' ...
Creating home directory `/home/ansible' ...
Copying files from `/etc/skel' ...
Enter new UNIX password:
Retype new UNIX password:
passwd: password updated successfully
Changing the user information for ansible
Enter the new value, or press ENTER for the default
   Full Name []:
   Room Number []:
   Work Phone []:
   Home Phone []:
   Other []:
Is the information correct? [Y/n] Y
# echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/50-ansible
# su ansible
$ cd ~
$ mkdir -p .ssh
$ echo "ssh-ed25519 <your ssh public key data from above, starts AAAA...> ansible-key" >> ~/.ssh/authorized_keys
$ exit
```

You might want to double check your dns name is working, make sure you can look up and ping your server:
On linux, this looks like:

```console
$ host vpn.example.com
vpn.example.com has address 5.34.114.9
$ ping -c 1 vpn.example.com
PING vpn.example.com (5.34.114.9): 56 data bytes
64 bytes from 5.34.114.9: icmp_seq=0 ttl=48 time=12.512 ms

--- vpn.example.com ping statistics ---
1 packets transmitted, 1 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 12.512/12.512/12.512/0.000 ms
```

# Step 4 - Configure server with ansible

- Install `ansible` on your host machine, if needed. This is left as an exercise to the reader.
- Add your server's dns name to the `hosts` file, by following the example.
- Edit variables in hosts file to your specifications:
  - this mainly means changing the username on the `management_username` and `management_ssh_pubkey_path` variables.
  - double check on what the actions are doing, for your awareness.
- Run the `wireguard_server.yaml`, i.e. from this directory:
  - `ansible-playbook wireguard_server.yaml`

This fully configures your server and reboots it, and now it is listening for connections, and almost set up. All you need to do now is create some client configs and tell your computer/phone/whatever to use them:

You can run `ansible-playbook wireguard_server.yaml` as many times as you want, it is "idempotent" which means that it ensures things are the way they are supposed to be regardless of whether it's run once or 100 times. This may be useful if you want to make a slight change.

# Step 5 - Create some client entries

I made a series of bash scripts to make management super easy, ansible loaded them onto the server for you.

On the server, ssh using your newly created management user:
```console
$ cd ~/simple-wireguard-admin
$ cd without_ipv6  # assuming you are not using ipv6, otherwise use the other directory
$ cp config.cfg.defaults config.cfg
$ nano config.cfg
...
[ Edit the file; at a minimum line 11: change example.com to your dns name]
[ Ctl-o to save ]
[ Ctl-x to exit ]
...
```

## Step 5A Create new user
On the server, as the management user:
```console
$ cd ~/simple-wireguard-admin
$ cd without_ipv6  # assuming you are not using ipv6, otherwise use the other directory
$ sudo ./create-key.sh my_phone
Client assigned v4 address: 172.16.0.2
wg genkey | tee /etc/wireguard/my_phone-privatekey | wg pubkey > /etc/wireguard/my_phone-publickey
wg set wg0 peer pKQubuxrTRe8SbhVIEAnWKvFOOGt0YWKT5GynWDRegX= allowed-ips 172.16.0.2/32
#######################
#                     #
#  A QR code appears  #
#                     #
#######################
Created: my_phone.conf for transfer to client
Take care of this configuration file - it contains the private key of the client. Transfer it securely,
then erase it. You can remove this user by running the command ./remove-user.sh my_phone
```

copy the file, as needed, or use the qr code on your wireguard app on your phone.

I wouldn't worry about deleting the <client name>.conf file as it can only be read by root.

## Step 5B Delete User
On the server, as the management user:
```console
$ cd ~/simple-wireguard-admin
$ cd without_ipv6  # assuming you are not using ipv6, otherwise use the other directory
$ sudo ./remove-user.sh my_phone
wg set wg0 peer pKQubuxrTRe8SbhVIEAnWKvFOOGt0YWKT5GynWDRegX= remove
```
