#!/bin/bash -e

# Helper functions
show_help() {
	echo "OmegaUp Installation script"
	echo -e "\t$0 -u git_username -m git_email"
	exit 1
}

# Configuration.
OMEGAUP_ROOT=/opt/omegaup
USER=`whoami`
MYSQL_PASSWORD=dd if=/dev/urandom count=1 bs=9 2>/dev/null | base64

# Get parameters
while getopts "u:m:01" optname; do
	case "$optname" in
		"u")
			GIT_USERNAME=$OPTARG
			;;
		"m")
			GIT_EMAIL=$OPTARG
			;;
		"0")
			SKIP_INSTALL=1
			;;
		"1")
			SKIP_NGINX=1
			;;
	esac
done

if [ "$GIT_USERNAME" == "" -o "$GIT_EMAIL" == "" ]; then
	show_help
fi

# Install everything needed.
if [ "$SKIP_INSTALL" != "1" ]; then
	curl http://www.dotdeb.org/dotdeb.gpg | sudo apt-key add -
	sudo apt-get update -q -y
	sudo apt-get upgrade -q -y
	sudo apt-get install -q -y nginx mysql-server mysql-client php5-fpm php5-cli php5-mysql php-pear php5-mcrypt php5-curl git phpunit g++ fp-compiler unzip openjdk-6-jdk openssh-client
fi

# Install SBT.
if [ ! -f /usr/bin/sbt ]; then
	sudo wget http://repo.typesafe.com/typesafe/ivy-releases/org.scala-sbt/sbt-launch//0.12.3/sbt-launch.jar -O /usr/bin/sbt-launch.jar
	cat > .sbt << EOF
#!/bin/sh
java -Xms512M -Xmx1536M -Xss1M -XX:+CMSClassUnloadingEnabled -XX:MaxPermSize=384M -jar \`dirname \$0\`/sbt-launch.jar "\$@"
EOF
	sudo mv .sbt /usr/bin/sbt
	sudo chmod +x /usr/bin/sbt
fi

# Add ngnix configuration.
if [ "$SKIP_NGINX" != "1" ]; then
	cat > .omegaup-conf << EOF
server {
listen       80;
server_name  localhost;

location / {
    root   /var/www/omegaup.com;
    index  index.php index.html;
}

# redirect server error pages to the static page /50x.html
#
error_page   500 502 503 504  /50x.html;
location = /50x.html {
    root   html;
}

# WebSockets.
location ^~ /api/contest/events/ {
    proxy_pass http://localhost:39613;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
}

location /api/ {
    rewrite ^/api/(.*)$ /api/ApiEntryPoint.php last;
}

# rewrites.
rewrite ^/contest/(.*)$ /contest.php?alias=\$1 last;
rewrite ^/arena/?$ /arena/index.php last;
rewrite ^/arena/[a-zA-Z0-9_+-]+/?$ /arena/contest.php last;
rewrite ^/arena/[a-zA-Z0-9_+-]+/scoreboard/?$ /arena/scoreboard.php last;
rewrite ^/arena/[a-zA-Z0-9_+-]+/admin/?$ /arena/admin.php last;
rewrite ^/arena/[a-zA-Z0-9_+-]+/practice/?$ /arena/practice.php last;

# pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
location ~ \.php$ {
    root           /var/www/omegaup.com;
    fastcgi_pass   127.0.0.1:9000;
    fastcgi_index  index.php;
    fastcgi_param  SCRIPT_FILENAME  /var/www/omegaup.com\$fastcgi_script_name;
    include        fastcgi_params;
}

# deny access to .htaccess files, if Apache's document root
# concurs with nginx's one
location ~ /\.ht {
    deny  all;
}
}
EOF
	sudo mv .omegaup-conf /etc/nginx/sites-enabled/default
	sudo /etc/init.d/nginx restart
fi

# Set up ssh/git.
if [ ! -f ~/.ssh/github.com ]; then
	mkdir ~/.ssh
	cat >> ~./ssh/config << EOF
Host github.com
IdentityFile /home/$USER/.ssh/github.com
User git
EOF
	git config --global user.name "$GIT_USERNAME"
	git config --global user.email "$GIT_EMAIL"
	git config --global credential.helper cache
	git config --global credential.helper 'cache --timeout=3600'
	ssh-keygen -t rsa -C "$GIT_EMAIL" -f ~/.ssh/github.com
	echo -e "Go to https://github.com/settings/ssh, click on \"Add SSH Key\" and enter:\n"
	cat ~/.ssh/github.com.pub
	echo -e "\n"
	read -s -n 1 -p "Press any key to continue"
fi

# Clone repository.
if [ ! -d $OMEGAUP_ROOT ]; then
	sudo mkdir $OMEGAUP_ROOT
	sudo chown $USER -R $OMEGAUP_ROOT
	git clone https://github.com/omegaup/omegaup.git $OMEGAUP_ROOT

	# Link the frontend to nginx.
	sudo ln -s $OMEGAUP_ROOT/frontend/www /var/www/omegaup.com

	# Generate the certificates required.
	cd $OMEGAUP_ROOT
	bin/gencerts.sh

	# Build the sandbox
	cd $OMEGAUP_ROOT/sandbox
	make

	# Build common
	cd $OMEGAUP_ROOT/common
	sbt package

	# Build runner
	cd $OMEGAUP_ROOT/runner
	sbt proguard

	# Build grader
	cd $OMEGAUP_ROOT/grader
	sbt proguard
fi

# check mysql

# Install config.php
if [ ! -f $OMEGAUP_ROOT/frontend/server/config.php ]; then
	cd $OMEGAUP_ROOT/frontend/server/
	cp config.php.sample config.php
	cat config.php | grep -v OMEGAUP_DB_ > config.pre1
fi

#chek php config.ini, set values for development

#check writable folders

#check and write config

#check db connection

#install user and db

#update config.php

#test curl

#test index with curl

#look for phpunit