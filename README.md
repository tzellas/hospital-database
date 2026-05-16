# HospitalDatabase

Darabase setup instruuctions

from gitbash/linux style terminal. UTF_8 encoded file
create the database 
createdb -U postgres hospital_db

from project root
build the databse 
psql -U postgres -d hospital_db -f sql/install.sql

fill the database 
psql -U postgres -d hospital_db -f sql/load.sql
