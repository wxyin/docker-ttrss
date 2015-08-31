FROM ubuntu
MAINTAINER Christian Lück <christian@lueck.tv>

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
  nginx git supervisor php5-fpm php5-cli php5-curl php5-gd php5-json \
  php5-pgsql php5-mysql php5-mcrypt && apt-get clean && rm -rf /var/lib/apt/lists/*

# enable the mcrypt module
RUN php5enmod mcrypt

#add ssl cerficate
RUN mkdir /etc/nginx/ssl
ADD nginx.key /etc/nginx/ssl/nginx.key
ADD nginx.crt /etc/nginx/ssl/nginx.crt

# add ttrss as the only nginx site
ADD ttrss.nginx.conf /etc/nginx/sites-available/ttrss
RUN ln -s /etc/nginx/sites-available/ttrss /etc/nginx/sites-enabled/ttrss
RUN rm /etc/nginx/sites-enabled/default

# install ttrss and patch configuration
WORKDIR /var/www
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl --no-install-recommends && rm -rf /var/lib/apt/lists/* \
    && curl -SL https://tt-rss.org/gitlab/fox/tt-rss/repository/archive.tar.gz?ref=master | tar xzC /var/www --strip-components 1 
    
RUN cp config.php-dist config.php

#add reeder theme
WORKDIR /tmp
RUN git clone https://github.com/tschinz/tt-rss_reeder_theme.git
RUN cp /tmp/tt-rss_reeder_theme/reeder.css /var/www/themes/
RUN cp -r /tmp/tt-rss_reeder_theme/reeder/ /var/www/themes/
RUN rm -rf /tmp/tt-rss_reeder_theme

#add fever plugin
RUN git clone https://github.com/dasmurphy/tinytinyrss-fever-plugin.git
RUN cp -r /tmp/tinytinyrss-fever-plugin/fever/ /var/www/plugins/
RUN rm -rf /tmp/tinytinyrss-fever-plugin

RUN apt-get purge -y git \
    && apt-get purge -y --auto-remove curl 

RUN chown www-data:www-data -R /var/www

# expose only nginx HTTP port
EXPOSE 443

# complete path to ttrss
ENV SELF_URL_PATH http://localhost

# expose default database credentials via ENV in order to ease overwriting
ENV DB_NAME ttrss
ENV DB_USER ttrss
ENV DB_PASS ttrss

# always re-configure database with current ENV when RUNning container, then monitor all services
ADD configure-db.php /configure-db.php
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD php /configure-db.php && supervisord -c /etc/supervisor/conf.d/supervisord.conf
