#lang datalog

edge(x, y).
edge(y, z).

parent(X, Y) :- edge(X, Z), edge(Z, Y).
