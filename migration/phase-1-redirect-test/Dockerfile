FROM wordpress:6.7.2-php8.3-apache

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/custom-entrypoint.sh && \
    chmod +x /usr/local/bin/custom-entrypoint.sh && \
    a2enmod rewrite && \
    printf '<Directory /var/www/html>\n    AllowOverride All\n    Require all granted\n</Directory>\n' > /etc/apache2/conf-available/wordpress-override.conf && \
    a2enconf wordpress-override

ENTRYPOINT ["/bin/bash", "/usr/local/bin/custom-entrypoint.sh"]
CMD ["apache2-foreground"]
