#!/bin/sh

if [ "$DB_SERVER" = "<to be defined>" ]; then
    echo >&2 'error: You requested automatic PrestaShop installation but MySQL server address is not provided '
    echo >&2 '  You need to specify DB_SERVER in order to proceed'
    exit 1
elif [ "$DB_SERVER" != "<to be defined>" ]; then
    RET=1
    while [ $RET -ne 0 ]; do
        echo "\n* Checking if $DB_SERVER is available..."
        mysql -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASSWD -e "status" > /dev/null 2>&1
        RET=$?

        if [ $RET -ne 0 ]; then
            echo "\n* Waiting for confirmation of MySQL service startup";
            sleep 5
        fi
    done
        echo "\n* DB server $DB_SERVER is available, let's continue !"
fi

# From now, stop at error
set -e

if [ ! -f ./config/settings.inc.php ] && [ ! -f ./install.lock ]; then

    echo "\n* Setting up install lock file..."
    touch ./install.lock

    echo "\n* Reapplying PrestaShop files for enabled volumes ...";

    if [ -d ./modules ]; then
        # init if empty
        echo "\n* Backup repo modules...";
        cp -n -R -T -p ./modules ./modules-backup
        echo "\n* Remove modules...";
        rm -r ./modules/*
    else
        echo "\n* No repo files to backup ...";
    fi

    if [ -d /tmp/data-ps/prestashop ]; then
        # init if empty
        echo "\n* Copying files from tmp directory ...";
        cp -n -R -T -p /tmp/data-ps/prestashop/ /var/www/html
    else
        echo "\n* No files to copy from tmp directory ...";
    fi

    if [ $PS_FOLDER_ADMIN != "admin" ] && [ -d /var/www/html/admin ]; then
        echo "\n* Renaming admin folder as $PS_FOLDER_ADMIN ...";
        mv /var/www/html/admin /var/www/html/$PS_FOLDER_ADMIN/
    fi

    echo "\n* Drop mysql database...";
    echo "\n* Dropping existing database $DB_NAME..."
    mysql -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASSWD -e "drop database if exists $DB_NAME;"

    echo "\n* Create mysql database...";
    echo "\n* Creating database $DB_NAME..."
    mysqladmin -h $DB_SERVER -P $DB_PORT -u $DB_USER create $DB_NAME -p$DB_PASSWD --force;

    echo "\n* Installing PrestaShop, this may take a while ...";

    export PS_DOMAIN=$(hostname -i)

    # steps_arg=$(echo '"database" "fixtures"')

    echo "\n* Launching the installer script..."
    runuser -g www-data -u www-data -- php -d memory_limit=-1 /var/www/html/install/index_cli.php \
    --domain="$PS_DOMAIN" --db_server=$DB_SERVER:$DB_PORT --db_name="$DB_NAME" --db_user=$DB_USER \
    --db_password=$DB_PASSWD --prefix="$DB_PREFIX" --firstname="John" --lastname="Doe" \
    --password=$ADMIN_PASSWD --email="$ADMIN_MAIL" --language=$PS_LANGUAGE --country=$PS_COUNTRY \
    --all_languages=0 --newsletter=0 --send_email=0 --ssl=0

    if [ $? -ne 0 ]; then
        echo 'warning: PrestaShop installation failed.'
    else
        echo "\n* Removing install folder..."
        rm -r /var/www/html/install/
    fi

    if [ -d ./modules-backup ]; then
        # init if empty
        echo "\n* Rollback repo modules...";
        cp -n -R -T -p ./modules-backup ./modules
        echo "\n* Remove backup directory...";
        rm -r ./modules-backup
    else
        echo "\n* No backup files to rollback...";
    fi

    echo "\n* Setup completed, removing lock file..."
    rm ./install.lock

elif [ ! -f ./config/settings.inc.php ] && [ -f ./install.lock ]; then

    echo "\n* Another setup is currently running..."
    sleep 10
    exit 42

elif [ -f ./config/settings.inc.php ] && [ -f ./install.lock ]; then

    echo "\n* Shop seems setup but remaining install lock still present..."
    sleep 10
    exit 42

else
    echo "\n* PrestaShop Core already installed...";
fi

# Disable stop at error
set +e

parameters_file_path="./app/config/parameters.php"

if [ ! -f "$parameters_file_path" ]; then
  echo "\n* Error: File '$parameters_file_path' does not exist. Update Database name manually."
else
    echo "\n* Updating parameters.php file...";

    # Update the database_name
    sed -i "s/'database_name' => '.*',/'database_name' => '${MYSQL_DATABASE}',/g" $parameters_file_path

    # Check for successful update
    if grep -q "'database_name' => '${MYSQL_DATABASE}'," $parameters_file_path; then
        echo "\n* Database name in '$parameters_file_path' updated successfully."
    else
        echo "\n* Error: Failed to update database name in '$parameters_file_path'."
    fi
fi

set -e

echo "\n* Almost ! Starting web server now\n";

exec php-fpm
