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


end # End of Util module


