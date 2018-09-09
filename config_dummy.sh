#copy this file and rename it "config.sh" add the real credentials in that file..

# make sure these are same as in your flyway/flyway.conf!!
usr="username"
pass="password"
db="db_name"
host="127.0.0.1"
port="3306"
version="v0.3"


flyway_dir=".."
# if you do not want any data in the migration set folder_data to empty string!!
folder_data="$flyway_dir/sql/data/general"