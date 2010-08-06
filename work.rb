#!/usr/bin/ruby


module Work # Beginning of Work module

require "P4"
require "singleton"
require "delegate"
require "rubygems"
require "parseconfig"
require "colorize"
require "util"

class Config
	
	include Singleton
	
	CFG_FILE = "/etc/work.rc"
	CFG_SEP = '='
	@@config = nil

	def initialize
		reload
	end
	
	def var(name, group = nil)
		if (group.nil? || @@config.params[group].nil?)
			@@config.params[name]
		else
			@@config.params[group][name]
		end
	end

	def reload
		@@config = ParseConfig.new(CFG_FILE, CFG_SEP)
	end

end

class P4_Work < DelegateClass(P4)

	include Singleton

	attr_accessor :client

	def initialize
		begin
			@p4obj = P4.new

			# to ignore "File(s) up-to-date"
			@p4obj.exception_level =  P4::RAISE_ERRORS
			@p4obj.connect
			@p4obj.run_login

			super(@p4obj)
			
			@client = @p4obj.run_client("-o").shift

		rescue P4Exception
			@p4obj.errors.each { |e| puts(e) }
		end

	end

	def revert_changelist(changelist)
		spec = run("describe", "-s", changelist)
		revs = spec[0]["rev"];
		files = spec[0]["depotFile"];
		
		revs.each_index { |x|
#			run("sync", files[x] + "#" + revs[x])		
			print files[x] + " # " + revs[x] + "\n"
		}
	end

end

class Term

	include Singleton

	attr_accessor :indent_val
	
	TEXT_COLOR = :light_black

	INFO_BULLET_COLOR = :light_green
	INFO_TEXT_COLOR = :light_black

	WARN_BULLET_COLOR = :light_yellow
	WARN_TEXT_COLOR = :yellow

	ERROR_BULLET_COLOR = :red
	ERROR_TEXT_COLOR = :light_red

	BULLET = "* "
	TAB_SIZE = 2
	TAB = " "

	def initialize
		@indent_val = 1
	end

	def format(msg, msg_color, sep = nil, sep_color = nil)
		ret = ""
		rows, cols = `stty size`.split.map { |x| x.to_i }
		cols -= 1
		cols -= sep.length if not sep.nil?
		arr = Utils.wrap_arr(msg, cols - 1)
		arr.each { |line| 
			if (! sep.nil?)
				if (! sep_color.nil?)
					ret << sep.colorize(sep_color)
				else
					ret << sep
				end
			end
			ret << line.colorize(msg_color) + "\n"
		}
		ret
	end

	def indent(x = 1)
		@indent_val += x
	end

	def indent_str
		TAB * TAB_SIZE * @indent_val
	end
	
	def text(msg)
		puts format(msg, TEXT_COLOR, indent_str)
	end

	def info(msg)
		sep = indent_str + BULLET
		puts format(msg, INFO_TEXT_COLOR, sep, INFO_BULLET_COLOR)
	end

	def warn(msg)
		sep = indent_str + BULLET
		puts format(msg, WARN_TEXT_COLOR, sep, WARN_BULLET_COLOR)
	end

	def error(msg)
		sep = indent_str + BULLET
		puts format(msg, ERROR_TEXT_COLOR, sep, ERROR_BULLET_COLOR)
	end

end

end # End of Work module

TERM = Work::Term.instance
CONFIG = Work::Config.instance
PERF = Work::P4_Work.instance

