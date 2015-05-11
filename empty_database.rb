require 'sqlite3'

db = SQLite3::Database.new('argph.db')

# Table for graphs.
db.execute 'DROP TABLE IF EXISTS Graphs'
db.execute 'CREATE TABLE Graphs(Id INTEGER PRIMARY KEY, String_Id TEXT, Title TEXT, X_Label TEXT, Y_Label TEXT)'

# Table for points.
db.execute 'DROP TABLE IF EXISTS Points'
db.execute 'CREATE TABLE Points(Point_Id INTEGER PRIMARY KEY, Value REAL, Timestamp INTEGER, Point_Label TEXT, Graph_Id INTEGER, FOREIGN KEY(Graph_Id) REFERENCES Graphs(Id))'