drop database if exists hex;
create database hex;
use hex;

create table t (
   x char(32) not null,
   unique index (x)
);

insert into hex.t values ('7468657365'), ('617265'),('6D79'),('7072696D617279'),('6B657973'),('696E'),('686578');
