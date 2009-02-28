class Forfait
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :aval, Integer
  property :amont, Integer
end

=begin
  Schema :
  CREATE TABLE "forfaits" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" VARCHAR(40) NOT NULL, "aval" INTEGER, "amont" INTEGER);
  Default informations :
  insert into forfaits (name, aval, amont) values ('Internet Intermédiaire',2,2);
  insert into forfaits (name, aval, amont) values ('Internet haute vitesse',20,10);
  insert into forfaits (name, aval, amont) values ('Internet haute vitesse Extrême',100,100);
  insert into forfaits (name, aval, amont) values ('Internet haute vitesse Extrême Plus',20,10);
  insert into forfaits (name, aval, amont) values ('Internet TGV 30',70,70);
  insert into forfaits (name, aval, amont) values ('Internet TGV 50',100,100);
  insert into forfaits (name, aval, amont) values ('Internet Intermédiaire Affaires',0,0);
  insert into forfaits (name, aval, amont) values ('Internet haute vitesse Affaires',0,0);
  insert into forfaits (name, aval, amont) values ('Internet haute vitesse Extrême Affaires',0,0);
  insert into forfaits (name, aval, amont) values ('Internet TGV 30 Affaires',100,100);
  insert into forfaits (name, aval, amont) values ('Internet TGV 50 Affaires',100,100);
=end