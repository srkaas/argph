require 'sqlite3'
require 'json'
require 'sinatra'

$db = SQLite3::Database.new('argph.db')
$db.results_as_hash = true

# Add a method that returns the only item in an array and raises an exception if there are multiple or zero.
class Array
  def only
    if self.size == 1
      return self.first
    else
      raise "Tried to take the only element out of a list that has multiple elements or zero elements. "
    end
  end
end

# Main site.
get '/' do
  erb :intro
end

# This could show a list of graphs, but we'd like the graphs to be slightly private, so it'll just have a creation form.
get '/graph' do
  erb :creategraph
end

# Post request that tries to create a new graph.
# TODO: Send a private token that the user needs to add points.
# TODO: Allow graphs to be edited and deleted.
post '/graph' do
  creation_statement = "INSERT INTO Graphs(Id, String_Id, Title, X_Label, Y_Label) VALUES(?, ?, ?, ?, ?)"

  # The ID for the new graph is the current maximum plus one, or just one if there are no graphs.
  id_array = $db.execute("SELECT Max(Id) FROM Graphs")
  current_max = id_array.only['Max(Id)'] || 0
  new_id = current_max.to_i + 1

  # If a text ID was provided, check that it's unique.
  if params['text_id']
    same_text_id = $db.execute("SELECT * FROM Graphs WHERE String_Id = ?", params['text_id'])
    halt(400, "That ID is taken. ") unless same_text_id.empty?
  end

  # Actually create the graph.
  $db.execute(creation_statement, new_id, params['text_id'].to_s, params['title'].to_s, params['xaxis'].to_s, params['yaxis'].to_s)

  # Return some information.
  {success: true, id: new_id, url: "/graph/#{new_id}"}.to_json
end

# Check if a string is a representation of a positive integer.
def represents_positive_integer(s)
  return false if s.empty?
  return false if s == '0'

  s.each_char do |c|
    return false unless '0123456789'.include? c
  end

  return true
end

# Query the database to gather the data for the current graph and its points in @graph_data and @points_data.
def get_graph_data
  # If the ID in the URL represents a positive integer, we interpret it as a standard numerical ID.
  # If it does not, we interpret it as a string ID.
  if represents_positive_integer(params['id'])
    @graph_data = $db.execute "SELECT * FROM Graphs WHERE Id = ?", params['id'].to_i
  else
    @graph_data = $db.execute("SELECT * FROM Graphs WHERE String_Id = ?", params['id'])
  end

  halt(404, 'Not a valid graph ID. ') if @graph_data.empty?

  @points_data = $db.execute "SELECT * FROM Points WHERE Graph_Id = ?", @graph_data.only['Id']
end

# View a graph.
get '/graph/:id' do
  get_graph_data

  # Data to be read into the graph.
  @js_data = @points_data.map {|points_datum| {x: points_datum['Timestamp'] * 1000, y: points_datum['Value'], hoverlabel: points_datum['Point_Label'] } }

  erb :showgraph, :layout => :graphlayout
end

# View the cumulative version of a graph (each point includes the sum of all data to its left, e.g. 1 3 5 becomes 1 4 9)
# TODO: Redirect to the cumulative version after adding a point.
get '/cumulative/:id' do
  get_graph_data

  # Data to be read into the graph.
  @js_data = []
  running_total = 0
  @points_data.each do |points_datum|
    running_total += points_datum['Value'].to_f
    @js_data << {x: points_datum['Timestamp'] * 1000, y: running_total, hoverlabel: points_datum['Point_Label']}
  end

  erb :showgraph, :layout => :graphlayout
end

# Add a point to a graph.
post '/graph/:id/point' do
  addition_statement = "INSERT INTO Points VALUES(?, ?, ?, ?, ?)"

  # New point ID is the maximum existing ID plus one, or just one if there are no points.
  id_array = $db.execute("SELECT Max(Point_Id) FROM Points")
  current_max = id_array.only['Max(Point_Id)'] || 0
  new_id = current_max.to_i + 1

  graph_id = params['graph_id'].to_i
  time = params['time'] || Time.new.to_i # Default to the current time.
  value = params['point_value'].to_f
  point_text = params['point_text'].to_s

  $db.execute addition_statement, new_id, value, time, point_text, graph_id

  {success: true, id: new_id, url: "/graph/#{new_id}"}.to_json
end