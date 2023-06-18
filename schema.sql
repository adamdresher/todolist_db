CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text UNIQUE NOT NULL
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  list_id int REFERENCES lists(id) ON DELETE CASCADE NOT NULL,
  description text NOT NULL,
  completed boolean DEFAULT false NOT NULL
);

