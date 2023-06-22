require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: 'todos')
    @logger = logger
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
    sql = "UPDATE lists SET name = $2 WHERE id = $1;"
    @db.query(sql, [new_name, id])
  end

  def create_new_todo(list_id, todo)
    # list = find_list(list_id)
    # id = next_id(list[:todos])
    # list[:todos] << { id: id, name: todo }
  end

  def delete_todo(list_id, todo_id)
    # list = find_list(list_id)
    # todo = select_todo(list[:todos], todo_id)
    # list[:todos].delete(todo)
  end

  def delete_list(id)
    sql = "DELETE FROM lists WHERE id = $1;"
    @db.query(sql, [id])
  end

  def update_todo_status(list_id, todo_id, new_status)
    # list = find_list(list_id)
    # todo = select_todo(list[:todos], todo_id)
    # todo[:complete] = new_status
  end

  def mark_all_todos_completed(list_id)
    # list = find_list(list_id)

    # if list[:todos].any?
    #   list[:todos].each { |todo| todo[:complete] = true }
    #   # session[:success] = 'All todos have been marked complete.'
    #   # @storage[:success] = 'All todos have been marked complete.'
    # end
  end

#   def message[]=(type, message)
#     @session[type] = message
#   end
# 
#   def message[](type)
#     @session[type]
#   end

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

  # Return 1 if no list found
  # def next_id(elements)
  #   max_id = elements.map { |element| element[:id] }.max || 0
  #   max_id + 1
  # end

  # def select_todo(todos, id)
  #   todos.select { |todo| todo[:id] === id.to_i }.first
  # end
end

