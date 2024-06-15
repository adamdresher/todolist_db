# frozen_string_literal: true

require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative 'database_persistance'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistance.rb'
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

helpers do
  def list_status(list)
    'complete' if list[:total_todos] > 0 && list[:total_todos] == list[:total_todos_completed]
  end

  def sort_lists(lists, &block)
    completed_lists, incompleted_lists = lists.partition { |list| list_status(list) }

    incompleted_lists.each(&block)
    completed_lists.each(&block)
  end

  def sort_todos(todos, &block)
    completed_todos, incompleted_todos = todos.partition { |todo| todo[:completed] }

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

# Validates for out of range list index and words
def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "The requested list does not exist."
  redirect "/lists"
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
    redirect '/lists/new'
  else
    puts "list_name: #{list_name} is a #{list_name}"
    @storage.create_new_list(list_name)

    session[:success] = 'A new list has been added.'
    redirect '/lists'
  end
end

# View a list
get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todos = @storage.find_todos_from_list(@list_id)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  erb :list, layout: :layout
end

# Render an edit list form
get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  erb :edit_list, layout: :layout
end

# Edits a list name
post '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  new_name = params[:list_name].strip
  error = error_for_list_name(new_name)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  if error
    session[:error] = error
    session[:invalid_name] = new_name
    redirect "lists/#{@list_id}/edit"
  else
    @storage.update_list_name(@list_id, new_name)
    session[:success] = "A list's name has been changed."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a list
post "/lists/:list_id/delete" do
  id = params[:list_id].to_i
  puts "id: #{id} is a #{id.class}"
  @storage.delete_list(id)

  session[:success] = "A list has been deleted."

  if env['HTTP_X_REQUESTED_WITH'] === 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = "A list has been deleted."
    redirect "/lists"
  end
end

# Add a todo to the list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todo = params[:todo].strip
  error = error_for_todo_name(@todo)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  if error
    session[:error] = error
    session[:invalid_todo_name] = @todo
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
  @list = load_list(@list_id)

  unless @list
    session[:error] = "The requested list does not exist."
    redirect "/lists"
  end

  @storage.delete_todo(@todo_id, @list_id)

  if env['HTTP_X_REQUESTED_WITH'] === 'XMLHttpRequest'
    status 204
  else
    session[:success] = "A todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update a todo from the list
post "/lists/:list_id/todos/:todo_id/update" do

  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  is_completed = (params[:complete] == 'true')

  @storage.update_todo_status(@todo_id, @list_id, is_completed)

  session[:success] = "A todo has been updated."
  
  redirect "/lists/#{@list_id}"
end

# Complete all todos from the list
post "/lists/:list_id/todos/complete_all" do
  @list_id = params[:list_id].to_i
  list = load_list(@list_id)

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

