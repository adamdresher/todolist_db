require 'pg'

class DatabasePersistence
  def initialize
    @db = PG.connect(dbname: 'todos')
  end

  def find_list(id)
    # @session[:lists].select { |list| list[:id] == id }.first
  end
 
  def all_lists
    sql = "SELECT * FROM lists;"
    result = @db.exec(sql)

    result.map do |tuple|
      sql = "SELECT * FROM todos WHERE list_id = #{tuple["id"]};"
      todos = @db.exec(sql).field_values('description')

      { id: tuple["id"], name: tuple["name"], todos: todos }
    end
  end

  def create_new_list(list_name)
    # id = next_id(@session[:lists])
    # @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def update_list_name(id, new_name)
    # list = find_list(id)
    # list[:name] = new_name
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
    # @session[:lists].reject! { |list| list[:id] == id }
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

  # private

  # Return 1 if no list found
  # def next_id(elements)
  #   max_id = elements.map { |element| element[:id] }.max || 0
  #   max_id + 1
  # end

  # def select_todo(todos, id)
  #   todos.select { |todo| todo[:id] === id.to_i }.first
  # end
end

