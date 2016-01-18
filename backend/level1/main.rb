require 'json'
require 'date'

class InvalidPeriodError < StandardError
end

class Car
	attr_reader :price_per_day, :price_per_km
	def initialize(cid, price_per_day, price_per_km)
		@cid = cid
		@price_per_day = price_per_day
		@price_per_km = price_per_km
	end
end

class Rental
	def initialize(car, start_date, end_date, distance)
		@car = car
		@start_date = start_date
		@end_date = end_date
		@distance = distance
	end

	def calculate_price
		number_of_days = calculate_number_of_days
		price_time_component = @car.price_per_day * number_of_days
		price_distance_component = @car.price_per_km * @distance
		price_time_component + price_distance_component
	end

	def calculate_number_of_days
		(@end_date - @start_date).to_i + 1
	end
end

def read_rentals
	data_file_name = "data.json"
	data = JSON.parse(File.read(data_file_name))
	
	cars = {}
	data['cars'].each do |json_car_data|
		begin
			cid = json_car_data.fetch('id')
			price_per_day = json_car_data.fetch('price_per_day')
			price_per_km = json_car_data.fetch('price_per_km')
		# Skip cars with inconsistent data
		rescue KeyError => e
			puts "[read_rentals, cars] Oops: #{e.message}"
			next
		end
		cars[cid] = Car.new(cid, price_per_day, price_per_km)
	end

	rentals = {}
	data['rentals'].each do |json_rental_data|
		begin
			rid = json_rental_data.fetch('id')
			cid = json_rental_data.fetch('car_id')
			distance = json_rental_data.fetch('distance')
			start_date = Date.strptime(json_rental_data.fetch('start_date'), '%Y-%m-%d')
			end_date = Date.strptime(json_rental_data.fetch('end_date'), '%Y-%m-%d')
			
			raise InvalidPeriodError, "Start date later than end date" if start_date > end_date
			
			car = cars[cid]
			rental = Rental.new(car, start_date, end_date, distance)

			rentals[rid] = rental
		# Skip rental with inconsistent data
		rescue KeyError, ArgumentError, InvalidPeriodError => e
			puts "[read_rentals, rentals] Oops: #{e.message}"
			next
		end
	end
	rentals
end

def level_1
	output = {'rentals' => []}
	read_rentals.each_pair do |rid, rental|
		price = rental.calculate_price
		output['rentals'] << {'id' => rid, 'price' => price}
	end
	write_output_json_file(output)
end

def write_output_json_file(output)
	puts JSON.pretty_generate(output)
	output_file_name = "output.json"
	File.open(output_file_name, 'w') do |output_file|
		# Not pretty output
  		# output_file.write(output.to_json)
  		# Pretty one ;-)
  		output_file.puts JSON.pretty_generate(output)
	end
end

if __FILE__ == $0
	level_1
end