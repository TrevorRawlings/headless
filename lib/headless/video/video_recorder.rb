require 'tempfile'

class Headless
  class VideoRecorder
    attr_accessor :pid_file_path, :tmp_file_path, :log_file_path, :ffmpeg_bin_path

    def initialize(display, dimensions, options = {})
      @display = display
      @dimensions = dimensions

      @pid_file_path = options.fetch(:pid_file_path, "/tmp/.headless_ffmpeg_#{@display}.pid")
      @tmp_file_path = options.fetch(:tmp_file_path, "/tmp/.headless_ffmpeg_#{@display}.mov")
      @log_file_path = options.fetch(:log_file_path, "/dev/null")
      @ffmpeg_bin_path = options.fetch(:ffmpeg_bin_path,   CliUtil.path_to('ffmpeg'))

      CliUtil.ensure_application_exists!(@ffmpeg_bin_path, "#{@ffmpeg_bin_path} not found on your system. Install it with sudo apt-get install ffmpeg")

      @codec = options.fetch(:codec, "qtrle")
      @nomouse = options.fetch(:nomouse, false)
      @frame_rate = options.fetch(:frame_rate, 30)
    end

    def capture_running?
      CliUtil.read_pid @pid_file_path
    end

    def start_capture
      nomouse = @nomouse ? "-draw_mouse 0" : "-draw_mouse 1"

      # ffmpeg no longer supports the color depth,
      # accepting trailing characters after the XxY
      # was actually a bug.
      #
      # -g 600 (GOP size) is no longer supported
     
      dimensions_trimmed = /(\d+x\d+)x/.match(@dimensions)[1]
      cmd = "#{@ffmpeg_bin_path} -y -r #{@frame_rate} -s #{dimensions_trimmed} -f x11grab #{nomouse} -i :#{@display} -vcodec #{@codec} #{@tmp_file_path}"
      CliUtil.fork_process(cmd, @pid_file_path, @log_file_path)
      at_exit do
        exit_status = $!.status if $!.is_a?(SystemExit)
        stop_and_discard
        exit exit_status if exit_status
      end
    end

    def stop_and_save(path)
      CliUtil.kill_process(@pid_file_path, :wait => true)
      if File.exists? @tmp_file_path
        begin
          FileUtils.mv(@tmp_file_path, path)
        rescue Errno::EINVAL
          nil
        end
      end
    end

    def stop_and_discard
      CliUtil.kill_process(@pid_file_path, :wait => true)
      begin
        FileUtils.rm(@tmp_file_path)
      rescue Errno::ENOENT
        # that's ok if the file doesn't exist
      end
    end
  end
end
