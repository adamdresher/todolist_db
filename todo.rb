# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  @storage = SessionPersistence.new(session)
end

helpers do
  def total_todos(list)
    list[:todos].size
  end

  def total_todos_remaining(list)
    list[:todos].select { |todo| !todo[:complete] }.size
  end

  def list_status(list)
    'complete' if total_todos(list) > 0 && total_todos_remaining(list).zero?
  end

  # Unused
  def sort_lists(lists, &block)
    completed_lists, incompleted_lists = lists.partition { |list| list_status(list) }

    incompleted_lists.each(&block)
    completed_lists.each(&block)
  end

  # Unused
  def sort_todos(todos, &block)
    completed_todos, incompleted_todos = todos.partition { |todo| todo[:complete] }

    incompleted_todos.each(&block)
    completed_todos.each(&block)
  end

  # Return nil if the name is valid
  def error_for_list_name(name)
    name = name.strip

    if !(1..100).cover? name.size
      'List name must be between 1 and 100 characters.'
    elsif @storage.all_lists.any? { |list| list[:name] == name }
      'List name must be unique.'
    end
  end

  # Return nil if the name is valid
  def error_for_todo_name(name)
    name = name.strip

    if !(1..100).cover? name.size
      'Todo must be between 1 and 100 characters.'
    end
  end
end

class SessionPersistence

  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].select { |list| list[:id] == id }.first
  end
 
  # Validates for out of range list index and words
  def load_list(id)
    list = find_list(id)
    return list if list

    # session[:error] = "The requested list does not exist."
    # redirect "/lists"
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def update_list_name(id, new_name)
    list = find_list(id)
    list[:name] = new_name
  end

  def create_new_todo(list_id, todo)
    list = find_list(list_id)
    id = next_id(list[:todos])
    list[:todos] << { id: id, name: todo }
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    todo = select_todo(list[:todos], todo_id)
    list[:todos].delete(todo)
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    list = load_list(list_id)
    todo = select_todo(list[:todos], todo_id)
    todo[:complete] = new_status
  end

  def mark_all_todos_completed(list_id)
    list = load_list(list_id)

    if list[:todos].any?
      list[:todos].each { |todo| todo[:complete] = true }
      # session[:success] = 'All todos have been marked complete.'
      # @storage[:success] = 'All todos have been marked complete.'
    end
  end

#   def message[]=(type, message)
#     @session[type] = message
#   end
# 
#   def message[](type)
#     @session[type]
#   end

  private

  # Return 1 if no list found
  def next_id(elements)
    max_id = elements.map { |element| element[:id] }.max || 0
    max_id + 1
  end

  def select_todo(todos, id)
    todos.select { |todo| todo[:id] === id.to_i }.first
  end
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render a new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    @storage[:error] = error
    redirect '/lists/new'
  else
    @storage.create_new_list(list_name)

    session[:success] = 'A new list has been added.'
    # @storage[:success] = 'A new list has been added.'
    redirect '/lists'
  end
end

# View a list
get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = @storage.load_list(@list_id)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  erb :list, layout: :layout
end

# Render an edit list form
get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = @storage.load_list(@list_id)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  erb :edit_list, layout: :layout
end

# Edits a list name
post '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = @storage.load_list(@list_id)
  new_name = params[:list_name].strip
  error = error_for_list_name(new_name)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  if error
    session[:error] = error
    # @storage[:error] = error
    session[:invalid_name] = new_name
    # @storage[:invalid_name] = new_name
    redirect "lists/#{@list_id}/edit"
  else
    @storage.update_list_name(@list_id, new_name.strip)
    session[:success] = "A list's name has been changed."
    # @storage[:success] = "A list's name has been changed."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a list
post "/lists/:list_id/delete" do
  id = params[:list_id].to_i
  @storage.delete_list(id)

  session[:success] = "A list has been deleted."
  # @storage[:success] = "A list has been deleted."

  if env['HTTP_X_REQUESTED_WITH'] === 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = "A list has been deleted."
    # @storage[:success] = "A list has been deleted."
    redirect "/lists"
  end
end

# Add a todo to the list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = @storage.load_list(@list_id)
  @todo = params[:todo].strip
  error = error_for_todo_name(@todo)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  if error
    session[:error] = error
    # @storage[:error] = error
    session[:invalid_todo_name] = @todo
    # @storage[:invalid_todo_name] = @todo
  else

    @storage.create_new_todo(@list_id, @todo)
    session[:success] = 'A new todo has been added.'
    # @storage[:success] = 'A new todo has been added.'
  end

  redirect "/lists/#{@list_id}"
end

# Delete a todo from the list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = @storage.load_list(@list_id)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  @storage.delete_todo(@list_id, @todo_id)

  if env['HTTP_X_REQUESTED_WITH'] === 'XMLHttpRequest'
    status 204
  else
    session[:success] = "A todo has been deleted."
    # @storage[:success] = "A todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update a todo from the list
post "/lists/:list_id/todos/:todo_id/update" do

  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  is_completed = (params[:complete] == 'true')

  @storage.update_todo_status(@list_id, @todo_id, is_completed)

  session[:success] = "A todo has been updated."
  # @storage[:success] = "A todo has been updated."
  
  redirect "/lists/#{@list_id}"
end

# Complete all todos from the list
post "/lists/:list_id/todos/complete_all" do
  @list_id = params[:list_id].to_i
  list = @storage.load_list(@list_id)

  unless list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  @storage.mark_all_todos_completed(@list_id)

  if list[:todos].any?
    session[:success] = 'All todos have been marked complete.'
  end

  redirect "/lists/#{@list_id}"
end
