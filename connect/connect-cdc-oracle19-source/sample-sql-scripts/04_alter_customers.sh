#!/bin/sh

echo 'Altering CUSTOMERS table with an optional column'

if [ "$1" = "ORCLPDB1" ]
then
docker exec -i oracle sqlplus C\#\#MYUSER/mypassword@//localhost:1521/$1 << EOF
  ALTER SESSION SET CONTAINER=CDB\$ROOT;
  EXECUTE DBMS_LOGMNR_D.BUILD(OPTIONS=>DBMS_LOGMNR_D.STORE_IN_REDO_LOGS);
  ALTER SESSION SET CONTAINER=ORCLPDB1;
  alter table CUSTOMERS add (
    country VARCHAR(50)
  );
  ALTER SESSION SET CONTAINER=CDB\$ROOT;
  EXECUTE DBMS_LOGMNR_D.BUILD(OPTIONS=>DBMS_LOGMNR_D.STORE_IN_REDO_LOGS);
  exit;
EOF
else
docker exec -i oracle sqlplus C\#\#MYUSER/mypassword@//localhost:1521/$1 << EOF
  ALTER SESSION SET CONTAINER=CDB\$ROOT;
  EXECUTE DBMS_LOGMNR_D.BUILD(OPTIONS=>DBMS_LOGMNR_D.STORE_IN_REDO_LOGS);
  alter table CUSTOMERS add (
    country VARCHAR(50)
  );
  ALTER SESSION SET CONTAINER=CDB\$ROOT;
  EXECUTE DBMS_LOGMNR_D.BUILD(OPTIONS=>DBMS_LOGMNR_D.STORE_IN_REDO_LOGS);
  exit;
EOF
fi
