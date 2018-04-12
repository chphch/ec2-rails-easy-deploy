#!/bin/bash

###
# Shell script for server settings
# AWS Utunbu LTS 16.04 LTS
# phusionpassenger
# ruby 2.4.3
# rails 5.0.6
# github
###

while read -p "Enter github repo name you want to deploy : " app_name && [ -z $app_name ] ; do
  echo "Github repo name shouldn't be empty"
done
while read -p "Enter github username : " github_username &&  [ -z $github_username ] ; do
  echo "Github username shouldn't be empty"
done
stty -echo
while read -p "Enter github password : " github_password && [ -z $github_password ] ; do
  echo "Github password shouldn't be empty"
done
stty echo; echo
while read -p "Enter deploy branch name : " deploy_branch && [ -z $deploy_branch ] ; do
  echo "Deploy branch name shouldn't be empty"
done

set -x

# Install RVM
sudo apt-get update
sudo apt-get install -y curl gnupg build-essential
sudo gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | sudo bash -s stable
sudo usermod -a -G rvm ubuntu
. /etc/profile.d/rvm.sh
if sudo grep -q secure_path /etc/sudoers; then sudo sh -c "echo export rvmsudo_secure_path=1 >> /etc/profile.d/rvm_secure_path.sh" && echo Environment variable installed; fi

# Install Ruby
bash -l -c "rvm install ruby-2.4.3"
bash -l -c "rvm --default use ruby 2.4.3"

# Install Bundler
gem install bundler --no-rdoc --no-ri

# Install Phusionpassenger
sudo apt-get install -y nodejs && sudo ln -sf /usr/bin/nodejs /usr/local/bin/node
sudo apt-get install -y dirmngr gnupg
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo apt-get install -y apt-transport-https ca-certificates
sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger xenial main > /etc/apt/sources.list.d/passenger.list'
sudo apt-get update
sudo apt-get install -y nginx-extras passenger

# Install Yarn for asset precompile
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get install yarn

# Add ssh publickey to github
[ ! -f $HOME/.ssh/id_rsa.pub ] && ssh-keygen -f /home/ubuntu/.ssh/id_rsa -N ''
curl -u "$github_username:$github_password" --data '{"title":"'ec2-$app_name'","key":"'$(cat $HOME/.ssh/id_rsa.pub)'"}' https://api.github.com/user/keys
ssh-keyscan github.com >> $HOME/.ssh/known_hosts

# Download app code from git remote repo
sudo mkdir -p /var/www/$app_name
sudo chown ubuntu: /var/www/$app_name
sudo -u ubuntu -H git clone --branch $deploy_branch git@github.com:$github_username/$app_name.git /var/www/$app_name/code

# Bundle install
cd /var/www/$app_name/code
bundle install --deployment --without development test

# Set secret_key_base
cd /var/www/$app_name/code
sed -i 's/<%= ENV\["SECRET_KEY_BASE"\] %>/'"$(bundle exec rake secret)"'/' config/secrets.yml

# Change authority of config files
cd /var/www/$app_name/code
chmod 700 config db
chmod 600 config/database.yml config/secrets.yml

# Config nginx settings
sudo sed -i 's/# include \/etc\/nginx\/passenger\.conf;/include \/etc\/nginx\/passenger\.conf;/' /etc/nginx/nginx.conf
sudo sed -i "s/\/usr\/bin\/passenger_free_ruby;/$path_to_ruby;/" /etc/nginx/passenger.conf
path_to_ruby=$(passenger-config about ruby-command | grep -m 1 'To use in Nginx' | sed 's/  To use in Nginx : passenger_ruby //')
sudo tee <<EOF /etc/nginx/sites-enabled/$app_name.conf
server {
    listen 80;
    server_name _;

    # Tell Nginx and Passenger where your app's 'public' directory is
    root /var/www/$app_name/code/public;

    # Turn on Passenger
    passenger_enabled on;
    passenger_ruby $path_to_ruby;
}
EOF
sudo rm /etc/nginx/sites-enabled/default

# Precompile & migrate
cd /var/www/$app_name/code
bundle exec rake assets:precompile db:migrate RAILS_ENV=production

# Start nginx engine
sudo service nginx restart

# Add aliases
echo 'alias appcode="/var/www/'$app_name'/code"' >> $HOME/.bash_aliases
echo 'alias update-appcode="appcode; git fetch origin; git checkout origin/'$deploy_branch'; git pull"' >> $HOME/.bash_aliases
echo 'alias precompile="appcode; bundle exec rake assets:precompile db:migrate RAILS_ENV=production"' >> $HOME/.bash_aliases
echo 'alias restart-nginx="sudo service nginx restart"' >> $HOME/.bash_aliases
echo 'alias deploy="update-appcode; appcode; bundle update; precompile; restart-nginx"' >> $HOME/.bash_aliases
echo 'alias nginx-error="cat /var/log/nginx/error.log | tail -n30"' >> $HOME/.bash_aliases
echo 'alias rails-log="cat /var/www/'$app_name'/code/log/production.log | tail -n30"' >> $HOME/.bash_aliases
. $HOME/.bashrc

set +x
