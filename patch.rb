require 'rubygems'
require 'session'

class Patch
  
	attr_accessor :file, :number, :target, :root, :stdout, :stderr, :exitcode, :patch_bin
  
	def initialize(file = '', root = '.', patch = 'patch')
		@file = file
		@root = root
		@patch_bin = patch
		parse if not @file.empty?
	end
  
	def parse
		@number = nil
		@target = ""
		begin
			(f = open(self.file)).each do |line|
				line.strip!
				if (/^\+\+\+/.match(line))
					junk1, @target, junk2 = line.split(/\s+/)
					break
				end
				unless (! /^\#/.match(line))
					if (/\@Patch number:/.match(line))
						junk1, @number = line.split(/\@Patch number:/)
					end
				end
			end

			if @number.nil?
				match_data = /_(\d\d)_/.match(file)
				if not match_data.nil? and not match_data[1].nil?
					@number = match_data[1]
				end
			end
			@number = @number.to_i
			@target.strip!
		rescue => ex
			nil
		ensure
			f.close
		end
	end
	
	def load(file)
		@file = file
		parse
	end

	def apply
		begin
			sess = Session.new
			input = open(@file, 'r')
			@stdout, @stderr = sess.execute "#{@patch_bin} #{@root}/#{@target}", :stdin => input
			@exitcode = sess.exit_status
		rescue
			raise $!
		ensure
			input.close if not input.nil?
                        sess.close
		end
	end 
  
end
