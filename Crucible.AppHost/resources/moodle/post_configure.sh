
# TODO: configure oauth before configuring issuerid and auth values below
echo confguring crucible...
php /var/www/html/admin/cli/cfg.php --name=curlsecurityblockedhosts --set='';
php /var/www/html/admin/cli/cfg.php --name=curlsecurityallowedport --set='';
#php /var/www/html/admin/cli/cfg.php --component=crucible --name=issuerid --set=1;
php /var/www/html/admin/cli/cfg.php --component=crucible --name=alloyapiurl --set=http://host.docker.internal:4402/api;
php /var/www/html/admin/cli/cfg.php --component=crucible --name=playerappurl --set=http://localhost:4301;
php /var/www/html/admin/cli/cfg.php --component=crucible --name=vmappurl --set=http://localhost:4303;
php /var/www/html/admin/cli/cfg.php --component=crucible --name=steamfitterapiurl --set=http://host.docker.internal:4400/api
echo confguring topomojo...
php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enableoauth --set=1;
#php /var/www/html/admin/cli/cfg.php --component=topomojo --name=issuerid --set=1;
php /var/www/html/admin/cli/cfg.php --component=topomojo --name=topomojoapiurl --set=http://host.docker.internal:5000/api;
php /var/www/html/admin/cli/cfg.php --component=topomojo --name=topomojobaseurl --set=http://localhost:4201;
php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enableapikey --set=1;
php /var/www/html/admin/cli/cfg.php --component=topomojo --name=apikey --set=la9_eT_RaK640Pb2WZgdvj84__iXSAC4
php /var/www/html/admin/cli/cfg.php --component=topomojo --name=enablemanagername --set=1;
php /var/www/html/admin/cli/cfg.php --component=topomojo --name=managername --set='Admin User';
moosh course-list | grep -q 'Test Course' || moosh course-create 'Test Course';
#php /var/www/html/admin/cli/cfg.php --name=auth --set='email,oauth2';
#moosh-new plugin-list;
#moosh plugin-install --release 2025070100 tool_userdebug
