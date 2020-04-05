create user testdata_ninja 
identified by testdata_ninja
default tablespace users
temporary tablespace temp
quota unlimited on users;

grant create session, create procedure, create type, create public synonym to testdata_ninja;