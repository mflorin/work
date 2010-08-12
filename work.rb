#!/usr/bin/ruby

class ProgressBar
	attr_accessor :title, :title_width, :bar_mark

	def title=(t)
		@title = t
		@title_width = t.length
		@format = "%-#{@title_width}s %3d%% %s %s"
	end
	
	def title_width=(tw)
		@title_width = tw
		@format = "%-#{@title_width}s %3d%% %s %s"
	end

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
		@last_str = ""
		@line = ""
		@line_len = 0
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

	def reset_line(cols = nil)
		cols, = width_height if cols.nil?
		@out.print "\r" + " " * cols + "\r"
		@line = ""
		@line_len = 0
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

	def prefix
		indent_str + BULLET
	end

	def print(msg, color = nil)

		str = msg
		if @line_len == 0
			if color.nil?
				@out.print prefix
			else
				@out.print prefix.colorize(color)
			end
			@out.flush
			@line_len += prefix.length
		end
		@line_len += msg.length
		str = str.colorize(color) if not color.nil?
		@line << str
		@out.print str
		@out.flush
	end

	def text(msg, bullet = nil, eol = nil)
		e = eol
		e = "\n" if eol.nil?
		if bullet.nil?
			format(msg, TEXT_COLOR, indent_str, nil, e)
		else
			format(msg, TEXT_COLOR, indent_str + BULLET, INFO_BULLET_COLOR, e)
		end
	end

	def eol
		print "\n"
		@line_len = 0
		@line = ""
	end
	
	def check_eol
		eol if @line_len > 0
	end
	
	def info(msg)
		check_eol
		display(msg, INFO_TEXT_COLOR, prefix, INFO_BULLET_COLOR)
	end

	def warn(msg)
		check_eol
		display(msg, WARN_TEXT_COLOR, prefix, WARN_BULLET_COLOR)
	end

	def error(msg)
		check_eol
		display(msg, ERROR_TEXT_COLOR, prefix, ERROR_BULLET_COLOR)
	end

	def action(msg)
		check_eol
		print prefix, ACTION_BULLET_COLOR
		print msg, ACTION_TEXT_COLOR
	end

	def ok(msg = nil)

		cols, = width_height
		if not msg.nil?
			action(msg)
		end

		ok_str_len = (LBRACKET + OK + RBRACKET).length
		ok_str = LBRACKET.colorize(BRACKET_COLOR) + OK.colorize(OK_COLOR) + \
				RBRACKET.colorize(BRACKET_COLOR)
		print ' ' + DOT * (cols - @line_len - ok_str_len - 2 - RPAD) + \
				' ' + ok_str
		eol

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
		print ' ' + DOT * (cols - @line_len - failure_str_len - 2 - RPAD) \
					+ ' ' + failure_str
		eol
	end

private

	def display(msg, msg_color = nil, sep = nil, sep_color = nil)
		cols, = width_height
		cols -= 1
		cols -= sep.length if not sep.nil?
		msg_color = TEXT_COLOR if msg_color.nil?
		arr = Utils.wrap_arr(msg, cols - 1)
		arr.each { |line| 
			print sep, sep_color
			print line, msg_color
			eol
		}
	end


end

end # End of Work module

TERM = Work::Term.instance
CONFIG = Work::Config.instance
PERF = Work::P4_Work.instance

