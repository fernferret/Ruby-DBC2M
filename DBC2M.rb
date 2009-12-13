#!/usr/bin/env ruby

require "FileUtils"

class Converter
	
	def initialize()
		@output = nil
	end
	
	def convertDBC2M(infile)
		puts "\nInput file set to: \"#{infile}.dbc\""
		if !Dir.exists?("#{infile}")
			FileUtils.mkdir "#{infile}"
			puts "I Created the Directory #{infile}!"
		else
			puts "The Directory #{infile} already exists!"
		end
		
		if File.exists?("#{infile}.dbc")
			input = File.open("#{infile}.dbc", "r")
			puts "I opened #{infile}.dbc Successfully!\n"
			FileUtils.cd "#{infile}"
			input.each{|line| ParseLine(line)}
		else
			puts "Can't open #{infile}.dbc! Exiting..."
			return
		end
	end
	
	def convertM2DBC(infile)
		puts "#######################"
		puts "#                     #"
		puts "# Not Yet Implmented! #"
		puts "#                     #"
		puts "#######################"
		# puts "\nInput file set to: \"#{infile}.m\""
		# if !Dir.exists?("#{infile}")
		# 	FileUtils.mkdir "#{infile}"
		# 	puts "I Created the Directory #{infile}!"
		# else
		# 	puts "The Directory #{infile} already exists!"
		# end
		
		# if File.exists?("#{infile}.m")
		# 	input = File.open("#{infile}.m", "r")
		# 	puts "I opened #{infile}.m Successfully!\n"
		# 	FileUtils.cd "#{infile}"
		# 	input.each{|line| ParseLine(line)}
		# else
		# 	puts "Can't open #{infile}.m! Exiting..."
		# end
	end
	
	def WriteMIntro(msgname, msgid)
		file = @output
		file.puts "function msg = #{msgname}()\n"
		file.puts "Broadcast = 20;\n"
		file.puts "  msg.name                    = '#{msgname}';\n"
		file.puts "  msg.description             = 'Description';\n"
		file.puts "  msg.protocol                = 'C$';\n"
		file.puts "  msg.module                  = 'PCM-1';\n"
		file.puts "  msg.bus_name                = 'CAN_1';\n"
		file.puts "\n"
		file.puts "  msg.idext                   = 'STANDARD';\n"
		file.puts "  msg.id                      = #{msgid};"
		file.puts "  msg.idmask                  = hex2dec('ffffffff');"
		file.puts "  msg.idinherit               =  0;"
		file.puts "  msg.payload_size            =  8;"
		file.puts "  msg.payload_value           = [];"
		file.puts "  msg.payload_mask            = [];"
		file.puts "  msg.interval                = Broadcast;"
		file.puts "\n\n"
		file.puts "    i = 1;"
	end
	
	def WriteMSignal(name, unit, start_bit, bit_length, byte_order, data_type, scale, offset, min, max)
		file = @output
		if @ran_once
			file.puts "    i=i+1;\n\n"
		else
			@ran_once = true
		end
		file.puts "    msg.fields(i).name = '#{name}';"
		file.puts "    msg.fields(i).units = '#{unit}';"
		file.puts "    msg.fields(i).start_bit = #{start_bit};"
		file.puts "    msg.fields(i).bit_length = #{bit_length};"
		file.puts "    msg.fields(i).byte_order = '#{byte_order}';"
		file.puts "    msg.fields(i).data_type = '#{data_type}';"
		file.puts "    msg.fields(i).scale = #{scale};"
		file.puts "    msg.fields(i).offset = #{offset};"
		file.puts "    msg.fields(i).minimum = #{min};" if min != 0
		file.puts "    msg.fields(i).maximum = #{max};" if max != 0
	end
	
	def ParseLine(line)
		# RegEX to capture Message lines
		if(line.match(/([A-Z_]+)\s([0-9]+)\s([a-zA-Z_0-9]+):\s([0-9])\s([a-zA-Z_]+)/) != nil)
			# This line is a message line
			@output.puts "\n\n%% end-of-file." if @output
			if File.exists?("#{$3}.m")
				@output = File.open("#{$3}.m", "w")
				puts "I created #{$3}.m Successfully!"
			else
				puts "#{$3}.m already exists! Opening to overwrite!"
				@output = File.open("#{$3}.m", "w")
			end	
			WriteMIntro($3, $2)
			puts "\n\nCreating message: #{$3}\n\n"
			@ran_once = false
		# RegEX to capture Signal Lines
		elsif(line.match(/[A-Z_]+\s(.*)\s:\s([0-9]+)\|([0-9]+)\@([01])([+-])\s\(([0-9.Ee-]+),([0-9.Ee-]+)\)\s\[([0-9.Ee-]+)\|([0-9.Ee-]+)\]\s"(.*)"\s(.*)/) != nil)
			
			# This line is a signal line
			startbit = $2.to_i
			bitlength = $3.to_i
			
			# Motorola = 0
			# Intel    = 1
			mot_intel = $4.to_i
			
			# Unsigned = +
			# Signed   = -
			
			if $5 == "+"
				datatype = "UNSIGNED"
			else
				datatype = "SIGNED"
			end
			
			# Not Needed: startbit = valuea
			# Not Needed: bitlength = valueb
			# Intel    = LITTLE_ENDIAN
			# Motorola = BIG_ENDIAN
			byteorder = "LITTLE_ENDIAN"
			# If Motorola
			# Special Case for 1 Bit signals
			byteorder = "BIG_ENDIAN" if mot_intel == 0 and bitlength == 1
			if mot_intel == 0 and bitlength != 1
				# -- Moved to cSB2BE: offset = (valuea/8)*8
				# TODO: Document This Equation
				startbit = convertStartBit2BE(startbit, bitlength)
				byteorder = "BIG_ENDIAN"
			end
			
			puts "#{$1} (Start Bit: #{startbit}; Length: #{bitlength}; Type: #{datatype})"
			factor = $6.to_f
			offset = $7.to_f
			min = $8.to_f
			max = $9.to_f
			units = $10
			
			WriteMSignal($1, $10, startbit, bitlength, byteorder, datatype, factor, offset, min, max)
		end
	end
	
	# Convert the start bit to big endian format for motorola signals
	def convertStartBit2BE(valuea, valueb)
		offset = (valuea/8)*8
		return (valuea+valueb-2*(valuea-offset+1)+1).abs
	end
end

if __FILE__ == $0
	convert = Converter.new
	if ARGV[0].upcase == "HELP"
		
	elsif ARGV[1] == nil
		puts "Wrong number of arguments, should be 2!"
	elsif ARGV[0].upcase == "M"
		convert.convertDBC2M(ARGV[1])
	elsif ARGV[0].upcase == "DBC"
		convert.convertM2DBC(ARGV[1])
	else
		puts "Input Error, please check your args"
	end
end