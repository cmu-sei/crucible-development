
# TODO: make sure that the dev container has the mounts set to 777 first
echo copying files
cp -r /moodle/theme /var/www/html/
cp -r /moodle/lib /var/www/html/
cp -r /moodle/admin/cli /var/www/html/admin/
