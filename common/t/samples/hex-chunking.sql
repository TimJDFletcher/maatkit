drop database if exists hex;
create database hex;
use hex;

create table t (
   x char(32) not null,
   unique index (x)
);

-- insert into hex.t values ('7468657365'), ('617265'),('6D79'),('7072696D617279'),('6B657973'),('696E'),('686578'),('49276D'),('61'),('6C6974746C65'),('746561706F74');
insert into hex.t values 
   ('746865736510900c'),
   ('1043493aff617265'),
   ('fe00000000026D79'),
   ('707ff2696D617279'),
   ('ca1000936B657973'),
   ('bed900019484696E'),
   ('f2989defee686578'),
   ('eeeeeeeeee49276D'),
   ('ffffffffffffff61'),
   ('10006C6974746C65'),
   ('1000746561706F74');


create table t_prefix (
   x char(32) not null,
   unique index (x)
);

insert into hex.t_prefix values ('0x7468657365'), ('0x617265'),('0x6D79'),('0x7072696D617279'),('0x6B657973'),('0x696E'),('0x686578'),('0x49276D'),('0x61'),('0x6C6974746C65'),('0x746561706F74');

create table t_mix (
   x char(32) not null,
   unique index (x)
);

insert into hex.t_mix values ('0x7468657365'), ('0x617265'),('6D79'),('0x7072696D617279'),('6B657973'),('696E'),('0x686578'),('49276D'),('61'),('0x6C6974746C65'),('746561706F74');
