module Utils

	def self.wrap_arr(msg, width)
		ret = []
		len = msg.length
		return ret << msg if width <= 0
		if (len > width) 

			last_i = 0
			i = 0;
			until i >= len
				tmp = i
				if msg[i].chr.eql? "\n"
					ret << msg[last_i .. i - 1]
					last_i = i + 1
					i += 2
					next
				end
				
				if (i - last_i >= width)
					until msg[i].chr.eql? ' ' or i <= last_i
						i -= 1
					end
					i = tmp if (i <= last_i)
					ret << msg[last_i .. i]
					last_i = i + 1
					next
				end
				i += 1
			end
			if (last_i != i and i == len): ret << msg[last_i .. i] end
		else
			ret << msg
		end
		ret
	end

	def self.term_width_height
	    # FIXME: I don't know how portable it is.
	    default_width = 80
		default_height = 25
		fallback = 0
	    begin
			tiocgwinsz = 0x5413
			data = [0, 0, 0, 0].pack("SSSS")
			if @out.ioctl(tiocgwinsz, data) >= 0 then
				rows, cols, xpixels, ypixels = data.unpack("SSSS")
				if rows <= 0 or cols <= 0 then fallback = 1 end
			else
				fallback = 1
			end
	    rescue Exception
			fallback = 1
	    end

		if fallback == 1
			rows, cols = `stty size`.split.map { |x| x.to_i }
			if rows <= 0 or cols <= 0
				rows = default_height
				cols = default_width
			end
		end
		
		[cols,rows]

	end


end # End of Util module


