require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: 'todos')
          end
    # @db = PG.connect(dbname: 'todos')
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(sql, *params)
    @logger.info "#{sql}: #{params}"
    @db.exec_params(sql, params)
  end

  def total_todos(list_id)
    find_todos_from_list(list_id).map { |todo| todo['description'] }.size
  end

  def total_todos_completed(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1 AND completed = 't';"
    query(sql, list_id).ntuples
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1;"
    result = query(sql, id)

    tuple = result.first
    list_id = tuple['id'].to_i
    todos = find_todos_from_list(list_id)

    { id: tuple['id'].to_i, name: tuple['name'], todos: todos }
  end
 
  def all_lists
    sql = "SELECT * FROM lists;"
    result = query(sql)

    result.map do |tuple|
      list_id = tuple['id'].to_i
      todos = find_todos_from_list(list_id)

      { id: tuple['id'].to_i, name: tuple['name'], todos: todos }
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    @db.query(sql, [list_name])
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2;"
    @db.query(sql, [new_name, id])
  end

  def delete_list(id)
    sql = "DELETE FROM lists WHERE id = $1;"
    @db.query(sql, [id])
  end

  def create_new_todo(list_id, description)
    sql = "INSERT INTO todos (description, list_id) VALUES ($1, $2);"
    @db.query(sql, [description, list_id])
  end

  def delete_todo(todo_id, list_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2;"
    @db.query(sql, [todo_id, list_id])
  end

  def update_todo_status(todo_id, list_id, new_status)
    sql = "UPDATE todos SET completed = $3 WHERE id = $1 AND list_id = $2;"
    @db.query(sql, [todo_id, list_id, new_status])
  end

  def mark_all_todos_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1;"
    @db.query(sql, [list_id])
  end

  private

  def find_todos_from_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1;"
    todos = query(sql, list_id)

    todos.map do |todo|
      { id: todo['id'].to_i,
        description: todo['description'],
        completed: todo['completed'] == 't' }
    end
  end
end

