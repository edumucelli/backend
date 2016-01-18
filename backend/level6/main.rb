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

	attr_accessor :start_date, :end_date, :distance
	def initialize(car, start_date, end_date, distance, options = {})
		@car = car
		@start_date = start_date
		@end_date = end_date
		@distance = distance
		# "For the moment", the only option is 'deductible_reduction',
		# but maybe in the future Rental can have new ones ... who knows?
		@options = options
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

	def calculate_deductible_reduction
		number_of_days = calculate_number_of_days
		@options['deductible_reduction'] ? number_of_days * 400 : 0
	end
end

class Action
	attr_accessor :amount, :type
	attr_reader :actor
	def initialize(actor)
		@actor = actor
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
			deductible_reduction = json_rental_data.fetch('deductible_reduction')
			
			raise InvalidPeriodError, "Start date later than end date" if start_date > end_date
			
			car = cars[cid]
			rental = Rental.new(car, start_date, end_date, distance, {'deductible_reduction' => deductible_reduction})

			rentals[rid] = rental
		# Skip rental with inconsistent data
		rescue KeyError, ArgumentError, InvalidPeriodError => e
			puts "[read_rentals, rentals] Oops: #{e.message}"
			next
		end
	end
	rentals
end

# I've supposed that rentals and their modifications are not contemporary,
# i.e., first rentals are done, then users change their minds, and update
# their rentals using Drivy. Therefore, a new method (that kind of repeat)
# the data read was created, just to simulate that rental and their modications
# are not introduced into the system at the same time.
# Here a modifications' hash is created, just to, later on, map the
# modifications to the rentals (simulate primary-key) in constant time (O(1)),
# instead of iterating on it (worst O(N)).
def read_rental_modifications
	data_file_name = "data.json"
	data = JSON.parse(File.read(data_file_name))
	modifications = {}
	if data.has_key?('rental_modifications')
		data['rental_modifications'].each do |rental_modification|
			modifications[rental_modification['rental_id']] = rental_modification
		end
	end
	modifications
end

def level_6
	output = {'rental_modifications' => []}

	rentals = read_rentals
	read_rental_modifications.each_pair do |rid, modification|
		rental = rentals[rid]
		original_price = rental.calculate_price
		original_commission = rental.calculate_commission
		original_insurance_fee = rental.calculate_insurance_fee
		original_assistance_fee = rental.calculate_assistance_fee
		original_drivy_fee = rental.calculate_drivy_fee
		original_deductible_reduction = rental.calculate_deductible_reduction

		modified_rental = rental.clone
		if modification.has_key?('start_date')
			modified_rental.start_date = Date.strptime(modification.fetch('start_date'), '%Y-%m-%d')
		end
		if modification.has_key?('end_date')
			modified_rental.end_date = Date.strptime(modification.fetch('end_date'), '%Y-%m-%d')
		end
		if modification.has_key?('distance')
			modified_rental.distance = modification.fetch('distance')
		end
		modified_price = modified_rental.calculate_price
		modified_commission = modified_rental.calculate_commission
		modified_insurance_fee = modified_rental.calculate_insurance_fee
		modified_assistance_fee = modified_rental.calculate_assistance_fee
		modified_drivy_fee = modified_rental.calculate_drivy_fee
		modified_deductible_reduction = modified_rental.calculate_deductible_reduction

		# Disclaimer: if the original and modified actions had the same amount, my
		# code will credit 0. I have not seen an example of this case in the output, thus
		# I consider that all actors must appear in the output, even when 'nothing' needs
		# to be done. However, that'd be simple to ignore actions when the difference is 0

		driver_action = Action.new('driver')
		driver_fee_diff = (original_price + original_deductible_reduction) - (modified_price + modified_deductible_reduction)
		# Driver paid more for the original rental than for the modified one, credit him
		if driver_fee_diff > 0
			driver_action.type = 'credit'
			driver_action.amount = driver_fee_diff
		else
			driver_action.type = 'debit'
			driver_action.amount = driver_fee_diff.abs
		end

		owner_action = Action.new('owner')
		owner_fee_diff = (original_price - original_commission) - (modified_price - modified_commission)
		# Owner received more for the the original rental than for the modified one, debit him
		if owner_fee_diff > 0
			owner_action.type = 'debit'
			owner_action.amount = owner_fee_diff
		else
			owner_action.type = 'credit'
			owner_action.amount = owner_fee_diff.abs
		end

		insurance_action = Action.new('insurance')
		insurance_fee_diff = original_insurance_fee - modified_insurance_fee
		# Insurance received more for the original rental than for the modified one, debit it
		if insurance_fee_diff > 0
			insurance_action.type = 'debit'
			insurance_action.amount = insurance_fee_diff
		else
			insurance_action.type = 'credit'
			insurance_action.amount = insurance_fee_diff.abs
		end

		assistance_action = Action.new('assistance')
		assistance_fee_diff = original_assistance_fee - modified_assistance_fee
		# Assistance received more for the original rental than for the modified one, debit it
		if assistance_fee_diff > 0
			assistance_action.type = 'debit'
			assistance_action.amount = assistance_fee_diff
		else
			assistance_action.type = 'credit'
			assistance_action.amount = assistance_fee_diff.abs
		end

		drivy_action = Action.new('drivy')
		drivy_fee_diff = (original_drivy_fee + original_deductible_reduction) - (modified_drivy_fee + modified_deductible_reduction)
		if drivy_fee_diff > 0
			drivy_action.type = 'debit'
			drivy_action.amount = drivy_fee_diff
		else
			drivy_action.type = 'credit'
			drivy_action.amount = drivy_fee_diff.abs
		end

		output['rental_modifications'] << {'id' => modification['id'], 'rental_id' => rid, 'actions' => [
			{"who" => driver_action.actor, 		'type' => driver_action.type, 	'amount' => driver_action.amount},
	        {"who" => owner_action.actor, 		'type' => owner_action.type, 'amount' => owner_action.amount},
	        {"who" => insurance_action.actor, 	'type' => insurance_action.type, 'amount' => insurance_action.amount},
			{'who' => assistance_action.actor, 	'type' => assistance_action.type, 'amount' => assistance_action.amount},
	        {"who" => drivy_action.actor, 		'type' => drivy_action.type, 'amount' => drivy_action.amount}
		]}
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
	level_6
end