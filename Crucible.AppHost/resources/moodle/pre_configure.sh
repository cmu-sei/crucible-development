# TODO: adjust permissions

echo removing old moodle core files
rm -rf /var/www/html/theme
rm -rf /var/www/html/lib
rm -rf /var/www/html/admin/cli

# TODO: make sure that the dev container has the mounts set to 777 first
echo copying moodle core files for debugging
cp -r /moodle/theme /var/www/html/
cp -r /moodle/lib /var/www/html/
cp -r /moodle/admin/cli /var/www/html/admin/
