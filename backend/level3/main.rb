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

	# Discount-priced intervals of days
	FIRST_RANGE_LOWER_INTERVAL = 1
	SECOND_RANGE_LOWER_INTERVAL = 4
	THIRD_RANGE_LOWER_INTERVAL = 10

	def initialize(car, start_date, end_date, distance)
		@car = car
		@start_date = start_date
		@end_date = end_date
		@distance = distance
	end

	# "To be as competitive as possible, we decide to have a decreasing pricing for longer rentals."
	def calculate_price	
		number_of_days = calculate_number_of_days
		if number_of_days == FIRST_RANGE_LOWER_INTERVAL
			price_time_component = @car.price_per_day
		elsif number_of_days > FIRST_RANGE_LOWER_INTERVAL && number_of_days <= SECOND_RANGE_LOWER_INTERVAL
			# price per day decreases by 10% after 1 day
			price_time_component = @car.price_per_day + (@car.price_per_day * (number_of_days - FIRST_RANGE_LOWER_INTERVAL) * 0.9)
		elsif number_of_days > SECOND_RANGE_LOWER_INTERVAL && number_of_days <= THIRD_RANGE_LOWER_INTERVAL
			# price per day decreases by 30% after 4 days
			price_time_component = @car.price_per_day + (@car.price_per_day * (SECOND_RANGE_LOWER_INTERVAL - FIRST_RANGE_LOWER_INTERVAL) * 0.9) +
														(@car.price_per_day * (number_of_days - SECOND_RANGE_LOWER_INTERVAL) * 0.7)
		else
			# price per day decreases by 50% after 10 days
			price_time_component = @car.price_per_day + (@car.price_per_day * (SECOND_RANGE_LOWER_INTERVAL - FIRST_RANGE_LOWER_INTERVAL) * 0.9) +
														(@car.price_per_day * (THIRD_RANGE_LOWER_INTERVAL - SECOND_RANGE_LOWER_INTERVAL) * 0.7) +
														(@car.price_per_day * (number_of_days - THIRD_RANGE_LOWER_INTERVAL) * 0.5)
		end
		price_distance_component = @car.price_per_km * @distance
		price_time_component.to_i + price_distance_component
	end

	def calculate_number_of_days
		(@end_date - @start_date).to_i + 1
	end

	# The commission is split like this:
	# - half goes to the insurance
	# - 1€/day goes to the roadside assistance
	# - the rest goes to us
	def calculate_commission
		price = calculate_price
		# We decide to take a 30% commission on the rental price to cover our costs and have a solid business model.
		(price * 0.3).to_i
	end

	def calculate_insurance_fee
		commission = calculate_commission
		commission / 2
	end

	def calculate_assistance_fee
		number_of_days = calculate_number_of_days
		number_of_days * 100
	end

	def calculate_drivy_fee
		commission = calculate_commission
		insurance_fee = calculate_insurance_fee
		assistance_fee = calculate_assistance_fee
		commission - (insurance_fee + assistance_fee)
	end

	def calculate_fees
		insurance_fee = calculate_insurance_fee
		assistance_fee = calculate_assistance_fee
		drivy_fee = calculate_drivy_fee
		return insurance_fee, assistance_fee, drivy_fee
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

def level_3
	output = {'rentals' => []}
	read_rentals.each_pair do |rid, rental|
		price = rental.calculate_price
		commission = rental.calculate_commission
		insurance_fee, assistance_fee, drivy_fee = rental.calculate_fees
		output['rentals'] << {'id' => rid, 'price' => price, 'commission' => {'insurance_fee' => insurance_fee,
													 	 					 'assistance_fee' => assistance_fee,
														 	 				 'drivy_fee' => drivy_fee }}
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
	level_3
end