#!/bin/sh


#make sure we are running form within flyway/ folder:
if [ ! -f `basename "$0"` ]; then
    echo -e "you must run this file from within the flyway/scripts/ folder!!"
    exit 0;
fi

# read config file
source "./config.sh";

# make sure we get all input parameters
if [[ ! $usr || ! $pass || ! $db || ! $version || ! $flyway_dir ]]; then {
    #note: folder_data may be empty so that is why it is not checked..
     echo -e "Please create your own copy of config.sh file (look at config_dummy.sh)..."
     exit 0;
} fi

running_pwd=${PWD}


folder_migrations="$flyway_dir/sql/migration"

filename_structure="V01_1__create_baseline_structure_$version.sql"
filename_data="V01_2__create_baseline_data_$version.sql"
filename_data_backup="backup_data_only.sql"
filename_full_backup="full_db_backup.sql"


run_fresh_migration() {
    echo -e "\n###########################################"
    echo -e "Running fresh migration \n"
    cd $flyway_dir
    ./app/flyway clean  
    ./app/flyway migrate  
    ./app/flyway info  
    cd $running_pwd
}

validate_current_migration() {
    echo -e "\n###########################################"
    echo -e "Validating current migration \n"
    cd $flyway_dir
    ./app/flyway migrate  
    should_we_continue
    cd $running_pwd
}

take_data_backup() {
    echo -e "\n###########################################"
    echo -e "Taking data backup \n"
    mysqldump \
        --user=$usr \
        --password=$pass \
	--host=$host \
        --no-create-info \
        --skip-triggers \
        --ignore-table=$db.flyway_schema_history \
        $db | \
        # foreign_key_checks comments at end of the file:
        sed '1s/^/set FOREIGN_KEY_CHECKS = 0; /' | \
        # foreign_key_checks comments at end of the file:
        sed '$aset FOREIGN_KEY_CHECKS = 1' > \
        $filename_data_backup
}

create_db_data_baseline_file() {
    echo -e "\n###########################################"
    echo -e "Taking data backup for migration data folder\n"
    mysqldump \
        --user=$usr \
        --password=$pass \
	--host=$host \
        --no-create-info \
        --skip-triggers \
        --complete-insert \
        --skip-extended-insert \
        --ignore-table=$db.flyway_schema_history \
        $db | \
        #remove unneeded comments
        sed '/\/\*.*/d' | \
        sed '/--.*/d' | \
        sed '/LOCK.*/d' | \
        sed '/UNLOCK.*/d' | \
        sed '/^\s*$/d' | \
        # foreign_key_checks comments at end of the file:
        sed '1s/^/set FOREIGN_KEY_CHECKS = 0; \n/' | \
        # foreign_key_checks comments at end of the file:
        sed '$aset FOREIGN_KEY_CHECKS = 1' > \
        $folder_data/$filename_data
}

take_full_backup() {
    echo -e "\n###########################################"
    echo -e "Taking full backup \n"
    mysqldump \
        --user=$usr \
        --password=$pass \
	--host=$host \
        $db > \
        $filename_full_backup
}

should_we_continue() {
    echo -e "\n###########################################"
    read -p "Do you want to continue (y/n)? " -n 1 -r
    echo #adds new line
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        exit 0;
    fi
}

remove_old_migration_files() {
    echo -e "\n###########################################"
    echo -e "Removing old migration files... \n"
    rm $folder_migrations/*.sql
}
remove_old_data_files() {
    echo -e "\n###########################################"
    echo -e "Removing old data files... \n"
    echo -e "NOTE: you should probably think about the other data folders also !!!"
    rm $folder_data/*.sql
}

create_db_structure_baseline_file() {
    echo -e "\n###########################################"
    echo -e "Creating structure baseline... \n"
    mysqldump \
        --user=$usr \
        --password=$pass \
	--host=$host \
        --skip-add-drop-table \
        --no-data  \
        --ignore-table=$db.flyway_schema_history \
        $db | \
        #remove unneeded string
        sed 's/ AUTO_INCREMENT=[0-9]*//g' | \
        #remove unneeded comments
        sed '/\/\*.*/d' | \
        sed '/--.*/d' | \
        # remove foreign_key_checks comments at start of the file:
        sed '1s/^/set FOREIGN_KEY_CHECKS = 0; /' | \
        # readd foreign_key_checks comments at end of the file:
        sed '$aset FOREIGN_KEY_CHECKS = 1' > \
        $folder_migrations/$filename_structure
}


write_data_to_db_from_data_file() {
    echo -e "\n###########################################"
    echo -e "Writing data back in to the db... \n"
    mysql \
        --user=$usr \
        --password=$pass \
	--host=$host \
        $db \
        < $filename_data_backup
}

##run when you do not have any important data in your db, or it is empty
join_migrations_reset_all() {
	run_fresh_migration
	take_data_backup
	take_full_backup
	should_we_continue
	remove_old_migration_files
	remove_old_data_files
	create_db_structure_baseline_file
	create_db_data_baseline_file
	run_fresh_migration
    #note: no extra data is written
}

##run when you have data in your db but you still want to join migrations (may be needed when in production)
## for this to work we should not have any data in our new migrations (check your flyway.conf)!!!
## You will have to start with an empty data folder after this
join_migrations_persist_data() {
    validate_current_migration
	take_data_backup
	take_full_backup
	should_we_continue
	remove_old_migration_files
	create_db_structure_baseline_file
	run_fresh_migration
	write_data_to_db_from_data_file
}

## run when you have data in your db but the db does not have correct flyway migrations for some reason
## but you want your db to start using them
## NOTE: you may get errors if your db structure has data that is not relevant
## for this to work we should not have any data in our migrations!!!
add_migrations_to_db_persist_data() {
	take_data_backup
	take_full_backup
	should_we_continue
	run_fresh_migration
	write_data_to_db_from_data_file
}

case $1 in
	help | "")
		echo "options: join_reset_all, join_persist_data, add_migrations_persist_data";
		;;
	run_fresh_migration)
		run_fresh_migration;
		;;
	take_data_backup)
		take_data_backup;
		;;
	take_full_backup)
		take_full_backup;
		;;
	should_we_continue)
		should_we_continue;
		;;
	remove_old_migration_files)
		remove_old_migration_files;
		;;
	remove_old_data_files)
		remove_old_data_files;
		;;
	create_db_structure_baseline_file)
		create_db_structure_baseline_file;
		;;
	write_data_to_db_from_data_file)
		write_data_to_db_from_data_file;
		;;
	join_reset_all)
		join_migrations_reset_all;
		;;
	join_persist_data)
		join_migrations_persist_data;
		;;
	add_migrations_persist_data)
		add_migrations_to_db_persist_data;
		;;
esac

exit 0;
