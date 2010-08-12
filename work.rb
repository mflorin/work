#!/usr/bin/ruby

class ProgressBar
	attr_accessor :title
end

module Work # Beginning of Work module

require "P4"
require "singleton"
require "delegate"
require "rubygems"
require "parseconfig"
require "colorize"
require "util"
require "progressbar"

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
	
	def [](var)
		@@config.params[var]
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

	attr_accessor :dent_val, :out
	
	TEXT_COLOR = :light_black

	INFO_BULLET_COLOR = :light_green
	INFO_TEXT_COLOR = :light_black

	WARN_BULLET_COLOR = :light_yellow
	WARN_TEXT_COLOR = :yellow

	ERROR_BULLET_COLOR = :red
	ERROR_TEXT_COLOR = :light_red

	ACTION_BULLET_COLOR = :light_green
	ACTION_TEXT_COLOR = :light_black

	OK_COLOR = :light_green
	FAILURE_COLOR = :light_red

	BRACKET_COLOR = :light_black

	BULLET = "* "
	TAB_SIZE = 2
	TAB = " "
	DOT = "."
	OK = "ok"
	FAILURE = "failed"
	LBRACKET = "["
	RBRACKET = "]"

	LPAD = 0
	RPAD = 10

	def initialize(out = nil)
		@dent_val = 1
		@last_len = 0
		if out.nil?
			@out = STDOUT 
		else
			@out = out
		end
	end

	def width_height
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

	def format(msg, msg_color, sep = nil, sep_color = nil, eol = "\n")
		ret = ""
		cols, = width_height
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
			ret << line.colorize(msg_color) + eol
		}
		ret
	end

	def reset_line(cols = nil)
		cols, = width_height if cols.nil?
		@out.print "\r" + " " * cols + "\r"
	end

	def indent(x = 1)
		@dent_val += x
	end

	def setdent(x = 0)
		@dent_val = x
	end

	def indent_str
		' ' * LPAD + TAB * TAB_SIZE * @dent_val
	end
	
	def text(msg)
		format(msg, TEXT_COLOR, indent_str)
	end

	def info(msg)
		sep = indent_str + BULLET
		@out.print format(msg, INFO_TEXT_COLOR, sep, INFO_BULLET_COLOR)
		@out.flush
	end

	def warn(msg)
		sep = indent_str + BULLET
		@out.print format(msg, WARN_TEXT_COLOR, sep, WARN_BULLET_COLOR)
		@out.flush
	end

	def error(msg)
		sep = indent_str + BULLET
		@out.print format(msg, ERROR_TEXT_COLOR, sep, ERROR_BULLET_COLOR)
		@out.flush
	end

	def action(msg)
		@last_len = (msg + indent_str + BULLET).length
		str = format(msg, ACTION_TEXT_COLOR, indent_str + BULLET, \
			ACTION_BULLET_COLOR, "")
		@out.print str
		@out.flush
	end

	def ok(msg = nil)

		cols, = width_height
		if not msg.nil?
			reset_line
			action(msg)
		end

		ok_str_len = (LBRACKET + OK + RBRACKET).length
		ok_str = LBRACKET.colorize(BRACKET_COLOR) + OK.colorize(OK_COLOR) + \
				RBRACKET.colorize(BRACKET_COLOR)
		@out.print ' ' + DOT * (cols - @last_len - ok_str_len - 2 - RPAD) + \
				' ' + ok_str + "\n"
		@out.flush
	end

	def failure(msg = nil)
		
		cols, = width_height
		if not msg.nil?
			reset_line(cols)
			action(msg)
		end

		failure_str_len = (LBRACKET + FAILURE + RBRACKET).length
		failure_str = LBRACKET.colorize(BRACKET_COLOR) + \
					FAILURE.colorize(FAILURE_COLOR) + \
					RBRACKET.colorize(BRACKET_COLOR)
		@out.print ' ' + DOT * (cols - @last_len - failure_str_len - 2 - RPAD) \
					+ ' ' + failure_str + "\n"
		@out.flush
	end

end

end # End of Work module

TERM = Work::Term.instance
CONFIG = Work::Config.instance
PERF = Work::P4_Work.instance

