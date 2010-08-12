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
		begin
		open(self.file).each do |line|
			line.strip!
			if (/^\+\+\+/.match(line))
				junk1, @target, junk2 = line.split(/\s+/)
			end
			unless (! /^\#/.match(line))
				if (/\@Patch number:/.match(line))
					junk1, @number = line.split(/\@Patch number:/)
				end
			end
		end
		if @number.nil?
			@number = /_\d\d_/.match(file)
		end
		@number.strip!
		@number = @number.to_i
		@target.strip!
		rescue => ex
			nil
		end
	end
	
	def load(file)
		@file = file
		parse
	end

	def apply
		sess = Session.new
		@stdout, @stderr = sess.execute "#{@patch_bin} #{@root}/#{@target}", :stdin => open(@file, 'r')
		@exitcode = sess.exit_status
	end 
  
end
