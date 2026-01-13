<style>
.reveal section[data-background-image] h1:not(:empty) {
  background: rgba(0, 0, 0, 0.6);
  padding: 20px 40px;
  border-radius: 10px;
  display: inline-block;
  color: AliceBlue;
}

.reveal pre code {
  max-height: 100%;
}

.reveal p code {
  background: #ececec;
}
</style>

# Le DevOps, c'est pas que du Dev ...

-v-

## Présentation

Julien Lenormand

<img src="./julien_lenormand_logo.png" alt="" width="786" style="margin-top: 200px" />

---

# D'où je pars

* le côté Dev du DevOps :  <!-- .element: class="fragment" -->
  * confier le déploiement à des ops<!-- .element: class="fragment" -->
  * intégrer le soft dans un OS qui sera flashé  <!-- .element: class="fragment" -->
  * produire une image Docker + manifest Helm pour déploiement sur k8s  <!-- .element: class="fragment" -->

* quelques expériences en Ops :  <!-- .element: class="fragment" -->
  * j'ai un PC Linux depuis + de 15 ans  <!-- .element: class="fragment" -->
  * j'ai fait du Docker cap et network avancé  <!-- .element: class="fragment" -->
  * j'ai fait un peu d'Ansible et de SSH, mais peu  <!-- .element: class="fragment" -->

---

# Là où je dois aller

* un ensemble de repos Python qui constituent une appli micro-services  <!-- .element: class="fragment" -->
  * la moitié que j'ai déjà faite tourner sur ma machine  <!-- .element: class="fragment" -->
  * la config que j'ai déjà un peu bidouillée  <!-- .element: class="fragment" -->
  * le fonctionnement que je connais  <!-- .element: class="fragment" -->

* à déployer sur un serveur vierge, tout juste loué dans le Cloud  <!-- .element: class="fragment" -->
* et tout doit fonctionner  <!-- .element: class="fragment" -->

---

# Jour 1 : achat du serveur

* je suis occupé à autre chose, je m'en occuperai demain  <!-- .element: class="fragment" -->

🤦  <!-- .element: class="fragment" -->

* lendemain matin un collègue me met en garde : le serveur se fait pilonner  <!-- .element: class="fragment" -->

---

# Jour 2 : sécurisation du serveur

* je me connecte en root avec la clé SSH  <!-- .element: class="fragment" -->
* je crée un utilisateur, je lui donne sudo  <!-- .element: class="fragment" -->
* je lui ajoute la clé publique SSH  <!-- .element: class="fragment" -->
* je teste la connexion  <!-- .element: class="fragment" -->

-v-

## Changement de la config SSH

`sudo nano /etc/ssh/sshd_config`  <!-- .element: class="fragment" -->

* on garde le port 22  <!-- .element: class="fragment" -->
* on interdit de se SSH en tant que root  <!-- .element: class="fragment" -->
* on interdit les connexions par mot de passe (uniquement par clé)  <!-- .element: class="fragment" -->

-v-

## Firewall : nftables

`sudo nano /etc/nftables.conf`  <!-- .element: class="fragment" -->

`sudo nft -c -f /etc/nftables.conf`  <!-- .element: class="fragment" -->

`sudo nft -f /etc/nftables.conf`  <!-- .element: class="fragment" -->

```python
flush ruleset
table inet filter {
	set cloudflare_ipv4 {
		type ipv4_addr;
		flags interval;
		elements = { 173.245.48.0/20, ... }
	}
	chain input {
		type filter hook input priority 0; policy drop;
		iif "lo" accept comment "Accept localhost"
		ct state established,related accept comment "Allow replies"
		tcp dport 22 ct state new accept comment "Allow SSH"
		ip saddr @cloudflare_ipv4 tcp dport 443 accept comment "Allow HTTPS from Cloudflare"
	}
...
```
<!-- .element: class="fragment" -->

-v-

## En vrac :

* "unattended upgrades" pour les MAJ de sécu  <!-- .element: class="fragment" -->
* password security (libpam-pwquality)  <!-- .element: class="fragment" -->
* "umask 027" pour limiter les droits des fichiers  <!-- .element: class="fragment" -->
* lynis pour faire des diagnostics sécu  <!-- .element: class="fragment" -->
* auditd pour surveiller les changements de certains fichiers  <!-- .element: class="fragment" -->
* kernel params tuning (sysctl)  <!-- .element: class="fragment" -->
* locale (UTC) et timezone (UTC)  <!-- .element: class="fragment" -->
* VPN  <!-- .element: class="fragment" -->
* ...  <!-- .element: class="fragment" -->

---

# Jour 3 : début du déploiement de l'appli

* création d'un nouvel utilisateur (no shell) pour exécuter les applicatifs  <!-- .element: class="fragment" -->
* les repos ne sont pas packagés, donc déploiement via git-clone + scp  <!-- .element: class="fragment" -->

🤦  <!-- .element: class="fragment" -->

* problèmes de droit : il faut chown + mv tous les fichiers  <!-- .element: class="fragment" -->
* c'est très fastidieux car manuel (spoiler : le premier déploiement ne sera pas le bon)  <!-- .element: class="fragment" -->

-v-

* l'un des repos a des dépendances complexes, il est packagé en conteneur

🤦  <!-- .element: class="fragment" -->

* l'image fait presque 4 Go, et j'ai pas de bande passante dans mon chalet du Jura  <!-- .element: class="fragment" -->

-v-

# Jour 4 : lancer les applicatifs

* avant, un fatras de shells, tmux, screen, nohop, ...  <!-- .element: class="fragment" -->
* mettre les choses à plat : systemd  <!-- .element: class="fragment" -->

* utilisation des units de nos dépendances (BD, Queue, ...)  <!-- .element: class="fragment" -->
* création des 10 units + 2 timers pour les applicatifs  <!-- .element: class="fragment" -->

`sudo systemctl daemon-reload`  <!-- .element: class="fragment" -->

`sudo systemctl status flup-api`  <!-- .element: class="fragment" -->

-v-

```python
[Unit]
Description=Flup API Service
After=network.target flup-component.service queue.service db.service

[Service]
Type=simple

User=flup
Group=flup

WorkingDirectory=/home/flup/api_flup/
Environment=PATH=/home/bda/api_flup/.venv/bin
ExecStart=/home/flup/api_flup/.venv/bin/python src/run_api.py

EnvironmentFile=/etc/flup/api_flup.env

Restart=on-failure
RestartSec=3s

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=flup.target
```

---

# Jour 4 : Configuration des dépendances

* 3 BDD différentes  <!-- .element: class="fragment" -->

🤦  <!-- .element: class="fragment" -->

* 1 système de queues  <!-- .element: class="fragment" -->
* pour chaque : lire les docs, configurer d'une façon différente  <!-- .element: class="fragment" -->

---

# Jour 5 : le reverse-proxy (Nginx)

`/etc/nginx/nginx.conf`  <!-- .element: class="fragment" -->

`/etc/nginx/conf.d/*.conf`  <!-- .element: class="fragment" -->

```nginx
log_format without_referrer_with_correlation_id
                    '$remote_addr - $remote_user [$time_iso8601] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_user_agent" id="$request_id"';
access_log  syslog:server=unix:/dev/log  without_referrer_with_correlation_id;  # not just /dev/stdout because would fail on systemd ExecPre

upstream flup_server {
    server 127.0.0.1:1234;
}

server {  # first server as fallback if nothing matches
    listen 1.2.3.4:443 default_server ssl;
    server_name _;  # an invalid name that can't be matched
}
```
<!-- .element: class="fragment" -->

-v-

```
server {  # Flup served to Cloudflare
    listen 1.2.3.4:443 ssl;
    http2 on;
    server_name flup.pluf.com;

    ssl_certificate /etc/ssl/certs/cloudflare-origin.pem;
    ssl_certificate_key /etc/ssl/private/cloudflare-origin.key;
 
    # only trust Cloudflare for providing a real IP
    set_real_ip_from 173.245.48.0/20;
    ...
    real_ip_header CF-Connecting-IP;

    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "no-referrer";
    
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
    proxy_set_header X-Request-ID $request_id;

    location / {
        proxy_pass http://flup_server;
    }
}
```

---

# Paramètres (environnement)

* plein de paramètres et de fichiers de config à gérer  <!-- .element: class="fragment" -->
* droits à gérer : root (si lus par systemd) ou utilisateur si lus au runtime  <!-- .element: class="fragment" -->

---

# Cloudflare

* tout un monde !  <!-- .element: class="fragment" -->
* features de sécurité :  <!-- .element: class="fragment" -->
  * reverse proxy  <!-- .element: class="fragment" -->
  * filtrage IP  <!-- .element: class="fragment" -->
  * Mirage  <!-- .element: class="fragment" -->
  * WAF  <!-- .element: class="fragment" -->
  * pages d'erreur custom  <!-- .element: class="fragment" -->
  * migration du nom de domaine  <!-- .element: class="fragment" -->
  * captcha Turnstile  <!-- .element: class="fragment" -->
  * Rocket Loader  <!-- .element: class="fragment" -->
  * ...  <!-- .element: class="fragment" -->

---

# Monitoring : CheckMk

![](./checkmk_example.png)

* systemd  <!-- .element: class="fragment" -->
* OTel  <!-- .element: class="fragment" -->

---

# Conclusion

* Merci ChatGPT (et consorts) pour leurs réponses  <!-- .element: class="fragment" -->
  * (et StackOverflow parfois aussi)  <!-- .element: class="fragment" -->
* je comprends pourquoi les gens aiment le Cloud et k8s  <!-- .element: class="fragment" -->
* je comprends pourquoi les gens détestent le Cloud et k8s  <!-- .element: class="fragment" -->
* la partie immergée de l'iceberg est quand même cachement grande !!  <!-- .element: class="fragment" -->

---

# Questions (et pensez au ROTI)

Repo : https://github.com/Lenormju/talk-devops-ops

Notes:

Sujets à venir :
* Bastion SSH
* Fail2Ban
* AppArmor
* Sudo
* CSP

---

## Abstract

Je suis convaincu par le DevOps, mais c'est facile de dire ça et de ne faire que du dev. Jusqu'à maintenant, je m'étais contenté de produire des images Docker, parfois quelques petits problèmes de droits de fichier ou d'interconnexion dans un Compose.

Mais aujourd'hui, j'ai du passer le cap, et plonger dans le côté Ops : pas de Cloud, juste un serveur nu, avec un OS tout juste installé dessus. Comment faire pour le sécuriser, configurer, déployer les applications dessus, et les monitorer ?

Je vais vous présenter ce que j'ai fait, les sujets que j'ai rencontrés, ce qu'il m'a fallu apprendre, mes erreurs, et ce que j'en retire. J'espère que vous en apprendrez un peu sur le monde de l'Ops, et que vous apprécierez les personnes qui font ce travail.
