module Utils

	def self.wrap(msg, width, sep = "\n")
		newmsg = msg
		len = newmsg.length
		sep_len = sep.length
		width -= sep_len
		return msg if width <= 0
		if (len > width) 

			last_i = 0
			i = width;
			until i >= newmsg.length
				tmp = i
				until newmsg[i].chr.eql? ' ' or i <= last_i
					i -= 1
				end
				i = tmp if (i <= last_i)
				i += 1 # insert the separator AFTER the last space
				last_i = i
				newmsg.insert(i, sep)
				i += sep_len + width
			end

		end
		newmsg
	end

	def self.wrap_arr(msg, width)
		ret = []
		len = msg.length
		return ret << msg if width <= 0
		if (len > width) 

			last_i = 0
			i = width;
			until i >= len
				tmp = i
				until msg[i].chr.eql? ' ' or i <= last_i
					i -= 1
				end
				i = tmp if (i <= last_i)
				ret << msg[last_i .. i]
				last_i = i + 1
				i += width
			end
			if (last_i != i): ret << msg[last_i .. i] end
		else
			ret << msg
		end
		ret
	end


end # End of Util module


