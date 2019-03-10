
mysql -e "CREATE DATABASE etherpad_lite_db /*\!40100 DEFAULT CHARACTER SET utf8 */;"
mysql -e "CREATE USER ${ETHERPAD_MYSQL_USER}@localhost IDENTIFIED BY '${ETHERPAD_MYSQL_PASS}';"
mysql -e "grant CREATE,ALTER,SELECT,INSERT,UPDATE,DELETE on etherpad_lite_db.* to '${ETHERPAD_MYSQL_USER}'@'localhost' identified by '${ETHERPAD_MYSQL_PASS}'"
mysql -e "FLUSH PRIVILEGES;"