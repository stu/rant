
# This file and the files in the rubyzip subdirectory contain a
# slightly modified (especially module and classnames) version of
# rubyzip 0.5.8. The following four sections are copied from the README
# file in the rubyzip package.
#
# = License
# 
# rubyzip is distributed under the same license as ruby. See
# http://www.ruby-lang.org/en/LICENSE.txt
# 
# 
# = Website and Project Home
# 
# http://rubyzip.sourceforge.net
# 
# http://sourceforge.net/projects/rubyzip
# 
# = Download (tarballs and gems)
# 
# http://sourceforge.net/project/showfiles.php?group_id=43107&package_id=35377
# 
# = Authors
# 
# Thomas Sondergaard (thomas at sondergaard.cc)
# 
# extra-field support contributed by Tatsuki Sugiura (sugi at nemui.org)


require 'delegate'
require 'singleton'
require 'fileutils'
require 'zlib'
require 'rant/archive/rubyzip/stdrubyext'
require 'rant/archive/rubyzip/ioextras'
require 'rant/tempfile'

module Zlib  #:nodoc:all
  if ! const_defined? :MAX_WBITS
    MAX_WBITS = Zlib::Deflate.MAX_WBITS
  end
end

module Rant; end
module Rant::Archive; end

module Rant::Archive::Rubyzip

  VERSION = '0.5.8'

  RUBY_MINOR_VERSION = RUBY_VERSION.split(".")[1].to_i

  # Ruby 1.7.x compatibility
  # In ruby 1.6.x and 1.8.0 reading from an empty stream returns 
  # an empty string the first time and then nil.
  #  not so in 1.7.x
  EMPTY_FILE_RETURNS_EMPTY_STRING_FIRST = RUBY_MINOR_VERSION != 7

  # ZipInputStream is the basic class for reading zip entries in a 
  # zip file. It is possible to create a ZipInputStream object directly, 
  # passing the zip file name to the constructor, but more often than not 
  # the ZipInputStream will be obtained from a ZipFile (perhaps using the 
  # ZipFileSystem interface) object for a particular entry in the zip 
  # archive.
  #
  # A ZipInputStream inherits IOExtras::AbstractInputStream in order
  # to provide an IO-like interface for reading from a single zip 
  # entry. Beyond methods for mimicking an IO-object it contains 
  # the method get_next_entry for iterating through the entries of 
  # an archive. get_next_entry returns a ZipEntry object that describes
  # the zip entry the ZipInputStream is currently reading from.
  #
  # Example that creates a zip archive with ZipOutputStream and reads it 
  # back again with a ZipInputStream.
  #
  #   require 'zip/zip'
  #   
  #   Zip::ZipOutputStream::open("my.zip") { 
  #     |io|
  #   
  #     io.put_next_entry("first_entry.txt")
  #     io.write "Hello world!"
  #   
  #     io.put_next_entry("adir/first_entry.txt")
  #     io.write "Hello again!"
  #   }
  #
  #   
  #   Zip::ZipInputStream::open("my.zip") {
  #     |io|
  #   
  #     while (entry = io.get_next_entry)
  #       puts "Contents of #{entry.name}: '#{io.read}'"
  #     end
  #   }
  #
  # java.util.zip.ZipInputStream is the original inspiration for this 
  # class.

  class ZipInputStream 
    include Rant::IOExtras::AbstractInputStream

    # Opens the indicated zip file. An exception is thrown
    # if the specified offset in the specified filename is
    # not a local zip entry header.
    def initialize(filename, offset = 0)
      super()
      @archiveIO = File.open(filename, "rb")
      @archiveIO.seek(offset, IO::SEEK_SET)
      @decompressor = NullDecompressor.instance
      @currentEntry = nil
    end
    
    def close
      @archiveIO.close
    end

    # Same as #initialize but if a block is passed the opened
    # stream is passed to the block and closed when the block
    # returns.    
    def ZipInputStream.open(filename)
      return new(filename) unless block_given?
      
      zio = new(filename)
      yield zio
    ensure
      zio.close if zio
    end

    # Returns a ZipEntry object. It is necessary to call this
    # method on a newly created ZipInputStream before reading from 
    # the first entry in the archive. Returns nil when there are 
    # no more entries.
    def get_next_entry
      @archiveIO.seek(@currentEntry.next_header_offset, 
		      IO::SEEK_SET) if @currentEntry
      open_entry
    end

    # Rewinds the stream to the beginning of the current entry
    def rewind
      return if @currentEntry.nil?
      @lineno = 0
      @archiveIO.seek(@currentEntry.localHeaderOffset, 
		      IO::SEEK_SET)
      open_entry
    end

    # Modeled after IO.read
    def read(numberOfBytes = nil)
      @decompressor.read(numberOfBytes)
    end

    protected

    def open_entry
      @currentEntry = ZipEntry.read_local_entry(@archiveIO)
      if (@currentEntry == nil) 
	@decompressor = NullDecompressor.instance
      elsif @currentEntry.compression_method == ZipEntry::STORED
	@decompressor = PassThruDecompressor.new(@archiveIO, 
						 @currentEntry.size)
      elsif @currentEntry.compression_method == ZipEntry::DEFLATED
	@decompressor = Inflater.new(@archiveIO)
      else
	raise ZipCompressionMethodError,
	  "Unsupported compression method #{@currentEntry.compression_method}"
      end
      flush
      return @currentEntry
    end

    def produce_input
      @decompressor.produce_input
    end
    
    def input_finished?
      @decompressor.input_finished?
    end
  end
  
  
  
  class Decompressor  #:nodoc:all
    CHUNK_SIZE=32768
    def initialize(inputStream)
      super()
      @inputStream=inputStream
    end
  end
  
  class Inflater < Decompressor  #:nodoc:all
    def initialize(inputStream)
      super
      @zlibInflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      @outputBuffer=""
      @hasReturnedEmptyString = ! EMPTY_FILE_RETURNS_EMPTY_STRING_FIRST
    end
    
    def read(numberOfBytes = nil)
      readEverything = (numberOfBytes == nil)
      while (readEverything || @outputBuffer.length < numberOfBytes)
	break if internal_input_finished?
	@outputBuffer << internal_produce_input
      end
      return value_when_finished if @outputBuffer.length==0 && input_finished?
      endIndex= numberOfBytes==nil ? @outputBuffer.length : numberOfBytes
      return @outputBuffer.slice!(0...endIndex)
    end
    
    def produce_input
      if (@outputBuffer.empty?)
	return internal_produce_input
      else
	return @outputBuffer.slice!(0...(@outputBuffer.length))
      end
    end

    # to be used with produce_input, not read (as read may still have more data cached)
    def input_finished?
      @outputBuffer.empty? && internal_input_finished?
    end

    private

    def internal_produce_input
      @zlibInflater.inflate(@inputStream.read(Decompressor::CHUNK_SIZE))
    end

    def internal_input_finished?
      @zlibInflater.finished?
    end

    # TODO: Specialize to handle different behaviour in ruby > 1.7.0 ?
    def value_when_finished   # mimic behaviour of ruby File object.
      return nil if @hasReturnedEmptyString
      @hasReturnedEmptyString=true
      return ""
    end
  end
  
  class PassThruDecompressor < Decompressor  #:nodoc:all
    def initialize(inputStream, charsToRead)
      super inputStream
      @charsToRead = charsToRead
      @readSoFar = 0
      @hasReturnedEmptyString = ! EMPTY_FILE_RETURNS_EMPTY_STRING_FIRST
    end
    
    # TODO: Specialize to handle different behaviour in ruby > 1.7.0 ?
    def read(numberOfBytes = nil)
      if input_finished?
	hasReturnedEmptyStringVal=@hasReturnedEmptyString
	@hasReturnedEmptyString=true
	return "" unless hasReturnedEmptyStringVal
	return nil
      end
      
      if (numberOfBytes == nil || @readSoFar+numberOfBytes > @charsToRead)
	numberOfBytes = @charsToRead-@readSoFar
      end
      @readSoFar += numberOfBytes
      @inputStream.read(numberOfBytes)
    end
    
    def produce_input
      read(Decompressor::CHUNK_SIZE)
    end
    
    def input_finished?
      (@readSoFar >= @charsToRead)
    end
  end
  
  class NullDecompressor  #:nodoc:all
    include Singleton
    def read(numberOfBytes = nil)
      nil
    end
    
    def produce_input
      nil
    end
    
    def input_finished?
      true
    end
  end
  
  class NullInputStream < NullDecompressor  #:nodoc:all
    include Rant::IOExtras::AbstractInputStream
  end
  
  class ZipEntry
    STORED = 0
    DEFLATED = 8
    
    attr_accessor  :comment, :compressed_size, :crc, :extra, :compression_method, 
      :name, :size, :localHeaderOffset, :zipfile, :fstype, :externalFileAttributes
    
    def initialize(zipfile = "", name = "", comment = "", extra = "", 
                   compressed_size = 0, crc = 0, 
		   compression_method = ZipEntry::DEFLATED, size = 0,
		   time  = Time.now)
      super()
      if name.starts_with("/")
	raise ZipEntryNameError, "Illegal ZipEntry name '#{name}', name must not start with /" 
      end
      @localHeaderOffset = 0
      @internalFileAttributes = 1
      @externalFileAttributes = 0
      @version = 52 # this library's version
      @fstype  = 0  # default is fat
      @zipfile, @comment, @compressed_size, @crc, @extra, @compression_method, 
	@name, @size = zipfile, comment, compressed_size, crc, 
	extra, compression_method, name, size
      @time = time
      unless ZipExtraField === @extra
        @extra = ZipExtraField.new(@extra.to_s)
      end
    end

    def time
      if @extra["UniversalTime"]
        @extra["UniversalTime"].mtime
      else
        # Atandard time field in central directory has local time
        # under archive creator. Then, we can't get timezone.
        @time
      end
    end
    alias :mtime :time
    
    def time=(aTime)
      unless @extra.member?("UniversalTime")
        @extra.create("UniversalTime")
      end
      @extra["UniversalTime"].mtime = aTime
      @time = aTime
    end

    def directory?
      return (%r{\/$} =~ @name) != nil
    end
    alias :is_directory :directory?

    def file?
      ! directory?
    end

    def local_entry_offset  #:nodoc:all
      localHeaderOffset + local_header_size
    end
    
    def local_header_size  #:nodoc:all
      LOCAL_ENTRY_STATIC_HEADER_LENGTH + (@name ?  @name.size : 0) + (@extra ? @extra.local_size : 0)
    end

    def cdir_header_size  #:nodoc:all
      CDIR_ENTRY_STATIC_HEADER_LENGTH  + (@name ?  @name.size : 0) + 
	(@extra ? @extra.c_dir_size : 0) + (@comment ? @comment.size : 0)
    end
    
    def next_header_offset  #:nodoc:all
      local_entry_offset + self.compressed_size
    end
    
    def to_s
      @name
    end
    
    protected
    
    def ZipEntry.read_zip_short(io)
      io.read(2).unpack('v')[0]
    end
    
    def ZipEntry.read_zip_long(io)
      io.read(4).unpack('V')[0]
    end
    public
    
    LOCAL_ENTRY_SIGNATURE = 0x04034b50
    LOCAL_ENTRY_STATIC_HEADER_LENGTH = 30
    
    def read_local_entry(io)  #:nodoc:all
      @localHeaderOffset = io.tell
      staticSizedFieldsBuf = io.read(LOCAL_ENTRY_STATIC_HEADER_LENGTH)
      unless (staticSizedFieldsBuf.size==LOCAL_ENTRY_STATIC_HEADER_LENGTH)
	raise ZipError, "Premature end of file. Not enough data for zip entry local header"
      end
      
      localHeader       ,
        @version          ,
	@fstype           ,
	@gpFlags          ,
	@compression_method,
	lastModTime       ,
	lastModDate       ,
	@crc              ,
	@compressed_size   ,
	@size             ,
	nameLength        ,
	extraLength       = staticSizedFieldsBuf.unpack('VCCvvvvVVVvv') 

      unless (localHeader == LOCAL_ENTRY_SIGNATURE)
	raise ZipError, "Zip local header magic not found at location '#{localHeaderOffset}'"
      end
      set_time(lastModDate, lastModTime)
      
      @name              = io.read(nameLength)
      extra              = io.read(extraLength)

      if (extra && extra.length != extraLength)
	raise ZipError, "Truncated local zip entry header"
      else
        if ZipExtraField === @extra
          @extra.merge(extra)
        else
          @extra = ZipExtraField.new(extra)
        end
      end
    end
    
    def ZipEntry.read_local_entry(io)
      entry = new(io.path)
      entry.read_local_entry(io)
      return entry
    rescue ZipError
      return nil
    end
  
    def write_local_entry(io)   #:nodoc:all
      @localHeaderOffset = io.tell
      
      io << 
	[LOCAL_ENTRY_SIGNATURE    ,
	0                  ,
	0                         , # @gpFlags                  ,
	@compression_method        ,
	@time.to_binary_dos_time     , # @lastModTime              ,
	@time.to_binary_dos_date     , # @lastModDate              ,
	@crc                      ,
	@compressed_size           ,
	@size                     ,
	@name ? @name.length   : 0,
	@extra? @extra.local_length : 0 ].pack('VvvvvvVVVvv')
      io << @name
      io << (@extra ? @extra.to_local_bin : "")
    end
    
    CENTRAL_DIRECTORY_ENTRY_SIGNATURE = 0x02014b50
    CDIR_ENTRY_STATIC_HEADER_LENGTH = 46
    
    def read_c_dir_entry(io)  #:nodoc:all
      staticSizedFieldsBuf = io.read(CDIR_ENTRY_STATIC_HEADER_LENGTH)
      unless (staticSizedFieldsBuf.size == CDIR_ENTRY_STATIC_HEADER_LENGTH)
	raise ZipError, "Premature end of file. Not enough data for zip cdir entry header"
      end
      
      cdirSignature          ,
	@version               , # version of encoding software
        @fstype                , # filesystem type
	@versionNeededToExtract,
	@gpFlags               ,
	@compression_method     ,
	lastModTime            ,
	lastModDate            ,
	@crc                   ,
	@compressed_size        ,
	@size                  ,
	nameLength             ,
	extraLength            ,
	commentLength          ,
	diskNumberStart        ,
	@internalFileAttributes,
	@externalFileAttributes,
	@localHeaderOffset     ,
	@name                  ,
	@extra                 ,
	@comment               = staticSizedFieldsBuf.unpack('VCCvvvvvVVVvvvvvVV')

      unless (cdirSignature == CENTRAL_DIRECTORY_ENTRY_SIGNATURE)
	raise ZipError, "Zip local header magic not found at location '#{localHeaderOffset}'"
      end
      set_time(lastModDate, lastModTime)
      
      @name                  = io.read(nameLength)
      if ZipExtraField === @extra
        @extra.merge(io.read(extraLength))
      else
        @extra = ZipExtraField.new(io.read(extraLength))
      end
      @comment               = io.read(commentLength)
      unless (@comment && @comment.length == commentLength)
	raise ZipError, "Truncated cdir zip entry header"
      end
    end
    
    def ZipEntry.read_c_dir_entry(io)  #:nodoc:all
      entry = new(io.path)
      entry.read_c_dir_entry(io)
      return entry
    rescue ZipError
      return nil
    end


    def write_c_dir_entry(io)  #:nodoc:all
      io << 
	[CENTRAL_DIRECTORY_ENTRY_SIGNATURE,
        @version                          , # version of encoding software
	@fstype                           , # filesystem type
	0                                 , # @versionNeededToExtract           ,
	0                                 , # @gpFlags                          ,
	@compression_method                ,
        @time.to_binary_dos_time             , # @lastModTime                      ,
	@time.to_binary_dos_date             , # @lastModDate                      ,
	@crc                              ,
	@compressed_size                   ,
	@size                             ,
	@name  ?  @name.length  : 0       ,
	@extra ? @extra.c_dir_length : 0  ,
	@comment ? comment.length : 0     ,
	0                                 , # disk number start
	@internalFileAttributes           , # file type (binary=0, text=1)
	@externalFileAttributes           , # native filesystem attributes
	@localHeaderOffset                ,
	@name                             ,
	@extra                            ,
	@comment                          ].pack('VCCvvvvvVVVvvvvvVV')

      io << @name
      io << (@extra ? @extra.to_c_dir_bin : "")
      io << @comment
    end
    
    def == (other)
      return false unless other.class == ZipEntry
      # Compares contents of local entry and exposed fields
      (@compression_method == other.compression_method &&
       @crc               == other.crc		     &&
       @compressed_size    == other.compressed_size    &&
       @size              == other.size	             &&
       @name              == other.name	             &&
       @extra             == other.extra             &&
       self.time.dos_equals(other.time))
    end

    def <=> (other)
      return to_s <=> other.to_s
    end

    def get_input_stream
      zis = ZipInputStream.new(@zipfile, localHeaderOffset)
      zis.get_next_entry
      if block_given?
	begin
	  return yield(zis)
	ensure
	  zis.close
	end
      else
	return zis
      end
    end


    def write_to_zip_output_stream(aZipOutputStream)  #:nodoc:all
      aZipOutputStream.copy_raw_entry(self)
    end

    def parent_as_string
      entry_name = name.chomp("/")
      slash_index = entry_name.rindex("/")
      slash_index ? entry_name.slice(0, slash_index+1) : nil
    end

    def get_raw_input_stream(&aProc)
      File.open(@zipfile, "rb", &aProc)
    end

    private
    def set_time(binaryDosDate, binaryDosTime)
      @time = Time.parse_binary_dos_format(binaryDosDate, binaryDosTime)
    rescue ArgumentError
      puts "Invalid date/time in zip entry"
    end
  end


  # ZipOutputStream is the basic class for writing zip files. It is 
  # possible to create a ZipOutputStream object directly, passing 
  # the zip file name to the constructor, but more often than not 
  # the ZipOutputStream will be obtained from a ZipFile (perhaps using the 
  # ZipFileSystem interface) object for a particular entry in the zip 
  # archive.
  #
  # A ZipOutputStream inherits IOExtras::AbstractOutputStream in order 
  # to provide an IO-like interface for writing to a single zip 
  # entry. Beyond methods for mimicking an IO-object it contains 
  # the method put_next_entry that closes the current entry 
  # and creates a new.
  #
  # Please refer to ZipInputStream for example code.
  #
  # java.util.zip.ZipOutputStream is the original inspiration for this 
  # class.

  class ZipOutputStream
    include Rant::IOExtras::AbstractOutputStream

    attr_accessor :comment

    # Opens the indicated zip file. If a file with that name already
    # exists it will be overwritten.
    def initialize(fileName)
      super()
      @fileName = fileName
      @outputStream = File.new(@fileName, "wb")
      @entrySet = ZipEntrySet.new
      @compressor = NullCompressor.instance
      @closed = false
      @currentEntry = nil
      @comment = nil
    end

    # Same as #initialize but if a block is passed the opened
    # stream is passed to the block and closed when the block
    # returns.    
    def ZipOutputStream.open(fileName)
      return new(fileName) unless block_given?
      zos = new(fileName)
      yield zos
    ensure
      zos.close if zos
    end

    # Closes the stream and writes the central directory to the zip file
    def close
      return if @closed
      finalize_current_entry
      update_local_headers
      write_central_directory
      @outputStream.close
      @closed = true
    end

    # Closes the current entry and opens a new for writing.
    # +entry+ can be a ZipEntry object or a string.
    def put_next_entry(entry, level = Zlib::DEFAULT_COMPRESSION)
      raise ZipError, "zip stream is closed" if @closed
      newEntry = entry.kind_of?(ZipEntry) ? entry : ZipEntry.new(@fileName, entry.to_s)
      init_next_entry(newEntry)
      @currentEntry=newEntry
    end

    def copy_raw_entry(entry)
      entry = entry.dup
      raise ZipError, "zip stream is closed" if @closed
      raise ZipError, "entry is not a ZipEntry" if !entry.kind_of?(ZipEntry)
      finalize_current_entry
      @entrySet << entry
      src_pos = entry.local_entry_offset
      entry.write_local_entry(@outputStream)
      @compressor = NullCompressor.instance
      @outputStream << entry.get_raw_input_stream { 
	|is| 
	is.seek(src_pos, IO::SEEK_SET)
	is.read(entry.compressed_size)
      }
      @compressor = NullCompressor.instance
      @currentEntry = nil
    end

    private
    def finalize_current_entry
      return unless @currentEntry
      finish
      @currentEntry.compressed_size = @outputStream.tell - @currentEntry.localHeaderOffset - 
	@currentEntry.local_header_size
      @currentEntry.size = @compressor.size
      @currentEntry.crc = @compressor.crc
      @currentEntry = nil
      @compressor = NullCompressor.instance
    end
    
    def init_next_entry(entry, level = Zlib::DEFAULT_COMPRESSION)
      finalize_current_entry
      @entrySet << entry
      entry.write_local_entry(@outputStream)
      @compressor = get_compressor(entry, level)
    end

    def get_compressor(entry, level)
      case entry.compression_method
	when ZipEntry::DEFLATED then Deflater.new(@outputStream, level)
	when ZipEntry::STORED   then PassThruCompressor.new(@outputStream)
      else raise ZipCompressionMethodError, 
	  "Invalid compression method: '#{entry.compression_method}'"
      end
    end

    def update_local_headers
      pos = @outputStream.tell
      @entrySet.each {
	|entry|
	@outputStream.pos = entry.localHeaderOffset
	entry.write_local_entry(@outputStream)
      }
      @outputStream.pos = pos
    end

    def write_central_directory
      cdir = ZipCentralDirectory.new(@entrySet, @comment)
      cdir.write_to_stream(@outputStream)
    end

    protected

    def finish
      @compressor.finish
    end

    public
    # Modeled after IO.<<
    def << (data)
      @compressor << data
    end
  end
  
  
  class Compressor #:nodoc:all
    def finish
    end
  end
  
  class PassThruCompressor < Compressor #:nodoc:all
    def initialize(outputStream)
      super()
      @outputStream = outputStream
      @crc = Zlib::crc32
      @size = 0
    end
    
    def << (data)
      val = data.to_s
      @crc = Zlib::crc32(val, @crc)
      @size += val.size
      @outputStream << val
    end

    attr_reader :size, :crc
  end

  class NullCompressor < Compressor #:nodoc:all
    include Singleton

    def << (data)
      raise IOError, "closed stream"
    end

    attr_reader :size, :compressed_size
  end

  class Deflater < Compressor #:nodoc:all
    def initialize(outputStream, level = Zlib::DEFAULT_COMPRESSION)
      super()
      @outputStream = outputStream
      @zlibDeflater = Zlib::Deflate.new(level, -Zlib::MAX_WBITS)
      @size = 0
      @crc = Zlib::crc32
    end
    
    def << (data)
      val = data.to_s
      @crc = Zlib::crc32(val, @crc)
      @size += val.size
      @outputStream << @zlibDeflater.deflate(data)
    end

    def finish
      until @zlibDeflater.finished?
	@outputStream << @zlibDeflater.finish
      end
    end

    attr_reader :size, :crc
  end
  

  class ZipEntrySet #:nodoc:all
    include Enumerable
    
    def initialize(anEnumerable = [])
      super()
      @entrySet = {}
      anEnumerable.each { |o| push(o) }
    end

    def include?(entry)
      @entrySet.include?(entry.to_s)
    end

    def <<(entry)
      @entrySet[entry.to_s] = entry
    end
    alias :push :<<

    def size
      @entrySet.size
    end
    alias :length :size

    def delete(entry)
      @entrySet.delete(entry.to_s) ? entry : nil
    end

    def each(&aProc)
      @entrySet.values.each(&aProc)
    end

    def entries
      @entrySet.values
    end

    # deep clone
    def dup
      newZipEntrySet = ZipEntrySet.new(@entrySet.values.map { |e| e.dup })
    end

    def == (other)
      return false unless other.kind_of?(ZipEntrySet)
      return @entrySet == other.entrySet      
    end

    def parent(entry)
      @entrySet[entry.parent_as_string]
    end

#TODO    attr_accessor :auto_create_directories
    protected
    attr_accessor :entrySet
  end


  class ZipCentralDirectory
    include Enumerable
    
    END_OF_CENTRAL_DIRECTORY_SIGNATURE = 0x06054b50
    MAX_END_OF_CENTRAL_DIRECTORY_STRUCTURE_SIZE = 65536 + 18
    STATIC_EOCD_SIZE = 22

    attr_reader :comment

    # Returns an Enumerable containing the entries.
    def entries
      @entrySet.entries
    end

    def initialize(entries = ZipEntrySet.new, comment = "")  #:nodoc:
      super()
      @entrySet = entries.kind_of?(ZipEntrySet) ? entries : ZipEntrySet.new(entries)
      @comment = comment
    end

    def write_to_stream(io)  #:nodoc:
      offset = io.tell
      @entrySet.each { |entry| entry.write_c_dir_entry(io) }
      write_e_o_c_d(io, offset)
    end

    def write_e_o_c_d(io, offset)  #:nodoc:
      io <<
	[END_OF_CENTRAL_DIRECTORY_SIGNATURE,
        0                                  , # @numberOfThisDisk
	0                                  , # @numberOfDiskWithStartOfCDir
	@entrySet? @entrySet.size : 0        ,
	@entrySet? @entrySet.size : 0        ,
	cdir_size                           ,
	offset                             ,
	@comment ? @comment.length : 0     ].pack('VvvvvVVv')
      io << @comment
    end
    private :write_e_o_c_d

    def cdir_size  #:nodoc:
      # does not include eocd
      @entrySet.inject(0) { |value, entry| entry.cdir_header_size + value }
    end
    private :cdir_size

    def read_e_o_c_d(io) #:nodoc:
      buf = get_e_o_c_d(io)
      @numberOfThisDisk                     = ZipEntry::read_zip_short(buf)
      @numberOfDiskWithStartOfCDir          = ZipEntry::read_zip_short(buf)
      @totalNumberOfEntriesInCDirOnThisDisk = ZipEntry::read_zip_short(buf)
      @size                                 = ZipEntry::read_zip_short(buf)
      @sizeInBytes                          = ZipEntry::read_zip_long(buf)
      @cdirOffset                           = ZipEntry::read_zip_long(buf)
      commentLength                         = ZipEntry::read_zip_short(buf)
      @comment                              = buf.read(commentLength)
      raise ZipError, "Zip consistency problem while reading eocd structure" unless buf.size == 0
    end
    
    def read_central_directory_entries(io)  #:nodoc:
      begin
	io.seek(@cdirOffset, IO::SEEK_SET)
      rescue Errno::EINVAL
	raise ZipError, "Zip consistency problem while reading central directory entry"
      end
      @entrySet = ZipEntrySet.new
      @size.times {
	@entrySet << ZipEntry.read_c_dir_entry(io)
      }
    end
    
    def read_from_stream(io)  #:nodoc:
      read_e_o_c_d(io)
      read_central_directory_entries(io)
    end
    
    def get_e_o_c_d(io)  #:nodoc:
      begin
	io.seek(-MAX_END_OF_CENTRAL_DIRECTORY_STRUCTURE_SIZE, IO::SEEK_END)
      rescue Errno::EINVAL
	io.seek(0, IO::SEEK_SET)
      rescue Errno::EFBIG # FreeBSD 4.9 returns Errno::EFBIG instead of Errno::EINVAL
	io.seek(0, IO::SEEK_SET)
      end
      buf = io.read
      sigIndex = buf.rindex([END_OF_CENTRAL_DIRECTORY_SIGNATURE].pack('V'))
      raise ZipError, "Zip end of central directory signature not found" unless sigIndex
      buf=buf.slice!((sigIndex+4)...(buf.size))
      def buf.read(count)
	slice!(0, count)
      end
      return buf
    end

    # For iterating over the entries.
    def each(&proc)
      @entrySet.each(&proc)
    end

    # Returns the number of entries in the central directory (and 
    # consequently in the zip archive).
    def size
      @entrySet.size
    end

    def ZipCentralDirectory.read_from_stream(io)  #:nodoc:
      cdir  = new
      cdir.read_from_stream(io)
      return cdir
    rescue ZipError
      return nil
    end

    def == (other) #:nodoc:
      return false unless other.kind_of?(ZipCentralDirectory)
      @entrySet.entries.sort == other.entries.sort && comment == other.comment
    end
  end
  
  
  class ZipError < StandardError ; end

  class ZipEntryExistsError            < ZipError; end
  class ZipDestinationFileExistsError  < ZipError; end
  class ZipCompressionMethodError      < ZipError; end
  class ZipEntryNameError              < ZipError; end

  # ZipFile is modeled after java.util.zip.ZipFile from the Java SDK.
  # The most important methods are those inherited from
  # ZipCentralDirectory for accessing information about the entries in
  # the archive and methods such as get_input_stream and
  # get_output_stream for reading from and writing entries to the
  # archive. The class includes a few convenience methods such as
  # #extract for extracting entries to the filesystem, and #remove,
  # #replace, #rename and #mkdir for making simple modifications to
  # the archive.
  #
  # Modifications to a zip archive are not committed until #commit or
  # #close is called. The method #open accepts a block following 
  # the pattern from File.open offering a simple way to 
  # automatically close the archive when the block returns. 
  #
  # The following example opens zip archive <code>my.zip</code> 
  # (creating it if it doesn't exist) and adds an entry 
  # <code>first.txt</code> and a directory entry <code>a_dir</code> 
  # to it.
  #
  #   require 'zip/zip'
  #   
  #   Zip::ZipFile.open("my.zip", Zip::ZipFile::CREATE) {
  #    |zipfile|
  #     zipfile.get_output_stream("first.txt") { |f| f.puts "Hello from ZipFile" }
  #     zipfile.mkdir("a_dir")
  #   }
  #
  # The next example reopens <code>my.zip</code> writes the contents of
  # <code>first.txt</code> to standard out and deletes the entry from 
  # the archive.
  #
  #   require 'zip/zip'
  #   
  #   Zip::ZipFile.open("my.zip", Zip::ZipFile::CREATE) {
  #     |zipfile|
  #     puts zipfile.read("first.txt")
  #     zipfile.remove("first.txt")
  #   }
  #
  # ZipFileSystem offers an alternative API that emulates ruby's 
  # interface for accessing the filesystem, ie. the File and Dir classes.
  
  class ZipFile < ZipCentralDirectory

    CREATE = 1

    attr_reader :name

    # Opens a zip archive. Pass true as the second parameter to create
    # a new archive if it doesn't exist already.
    def initialize(fileName, create = nil)
      super()
      @name = fileName
      @comment = ""
      if (File.exist?(fileName))
	File.open(name, "rb") { |f| read_from_stream(f) }
      elsif (create)
	@entrySet = ZipEntrySet.new
      else
	raise ZipError, "File #{fileName} not found"
      end
      @create = create
      @storedEntries = @entrySet.dup
    end

    # Same as #new. If a block is passed the ZipFile object is passed
    # to the block and is automatically closed afterwards just as with
    # ruby's builtin File.open method.
    def ZipFile.open(fileName, create = nil)
      zf = ZipFile.new(fileName, create)
      if block_given?
	begin
	  yield zf
	ensure
	  zf.close
	end
      else
	zf
      end
    end

    # Returns the zip files comment, if it has one
    attr_accessor :comment

    # Iterates over the contents of the ZipFile. This is more efficient
    # than using a ZipInputStream since this methods simply iterates
    # through the entries in the central directory structure in the archive
    # whereas ZipInputStream jumps through the entire archive accessing the
    # local entry headers (which contain the same information as the 
    # central directory).
    def ZipFile.foreach(aZipFileName, &block)
      ZipFile.open(aZipFileName) {
	|zipFile|
	zipFile.each(&block)
      }
    end
    
    # Returns an input stream to the specified entry. If a block is passed
    # the stream object is passed to the block and the stream is automatically
    # closed afterwards just as with ruby's builtin File.open method.
    def get_input_stream(entry, &aProc)
      get_entry(entry).get_input_stream(&aProc)
    end

    # Returns an output stream to the specified entry. If a block is passed
    # the stream object is passed to the block and the stream is automatically
    # closed afterwards just as with ruby's builtin File.open method.
    def get_output_stream(entry, &aProc)
      newEntry = entry.kind_of?(ZipEntry) ? entry : ZipEntry.new(@name, entry.to_s)
      if newEntry.directory?
	raise ArgumentError,
	  "cannot open stream to directory entry - '#{newEntry}'"
      end
      zipStreamableEntry = ZipStreamableStream.new(newEntry)
      @entrySet << zipStreamableEntry
      zipStreamableEntry.get_output_stream(&aProc)      
    end

    # Returns the name of the zip archive
    def to_s
      @name
    end

    # Returns a string containing the contents of the specified entry
    def read(entry)
      get_input_stream(entry) { |is| is.read } 
    end

    # Convenience method for adding the contents of a file to the archive
    def add(entry, srcPath, &continueOnExistsProc)
      continueOnExistsProc ||= proc { false }
      check_entry_exists(entry, continueOnExistsProc, "add")
      newEntry = entry.kind_of?(ZipEntry) ? entry : ZipEntry.new(@name, entry.to_s)
      if is_directory(newEntry, srcPath)
	@entrySet << ZipStreamableDirectory.new(newEntry)
      else
	@entrySet << ZipStreamableFile.new(newEntry, srcPath)
      end
    end
    
    # Removes the specified entry.
    def remove(entry)
      @entrySet.delete(get_entry(entry))
    end
    
    # Renames the specified entry.
    def rename(entry, newName, &continueOnExistsProc)
      foundEntry = get_entry(entry)
      check_entry_exists(newName, continueOnExistsProc, "rename")
      foundEntry.name=newName
    end

    # Replaces the specified entry with the contents of srcPath (from 
    # the file system).
    def replace(entry, srcPath)
      check_file(srcPath)
      add(remove(entry), srcPath)
    end

    # Extracts entry to file destPath.
    def extract(entry, destPath, &onExistsProc)
      onExistsProc ||= proc { false }
      foundEntry = get_entry(entry)
      if foundEntry.is_directory
	create_directory(foundEntry, destPath, &onExistsProc)
      else
	write_file(foundEntry, destPath, &onExistsProc) 
      end
    end

    # Commits changes that has been made since the previous commit to 
    # the zip archive.
    def commit
     return if ! commit_required?
      on_success_replace(name) {
	|tmpFile|
	ZipOutputStream.open(tmpFile) {
	  |zos|

	  @entrySet.each { |e| e.write_to_zip_output_stream(zos) }
	  zos.comment = comment
	}
	true
      }
      initialize(name)
    end

    # Closes the zip file committing any changes that has been made.
    def close
      commit
    end

    # Returns true if any changes has been made to this archive since
    # the previous commit
    def commit_required?
      return @entrySet != @storedEntries || @create == ZipFile::CREATE
    end

    # Searches for entry with the specified name. Returns nil if 
    # no entry is found. See also get_entry
    def find_entry(entry)
      @entrySet.detect { 
	|e| 
	e.name.sub(/\/$/, "") == entry.to_s.sub(/\/$/, "")
      }
    end

    # Searches for an entry just as find_entry, but throws Errno::ENOENT
    # if no entry is found.
    def get_entry(entry)
      selectedEntry = find_entry(entry)
      unless selectedEntry
	raise Errno::ENOENT, entry
      end
      return selectedEntry
    end

    # Creates a directory
    def mkdir(entryName, permissionInt = 0) #permissionInt ignored
      if find_entry(entryName)
        raise Errno::EEXIST, "File exists - #{entryName}"
      end
      @entrySet << ZipStreamableDirectory.new(ZipEntry.new(name, entryName.to_s.ensure_end("/")))
    end

    private

    def create_directory(entry, destPath)
      if File.directory? destPath
	return
      elsif File.exist? destPath
	if block_given? && yield(entry, destPath)
	  File.rm_f destPath
	else
	  raise ZipDestinationFileExistsError,
	    "Cannot create directory '#{destPath}'. "+
	    "A file already exists with that name"
	end
      end
      Dir.mkdir destPath
    end

    def is_directory(newEntry, srcPath)
      srcPathIsDirectory = File.directory?(srcPath)
      if newEntry.is_directory && ! srcPathIsDirectory
	raise ArgumentError,
	  "entry name '#{newEntry}' indicates directory entry, but "+
	  "'#{srcPath}' is not a directory"
      elsif ! newEntry.is_directory && srcPathIsDirectory
	newEntry.name += "/"
      end
      return newEntry.is_directory && srcPathIsDirectory
    end

    def check_entry_exists(entryName, continueOnExistsProc, procedureName)
      continueOnExistsProc ||= proc { false }
      if @entrySet.detect { |e| e.name == entryName }
	if continueOnExistsProc.call
	  remove get_entry(entryName)
	else
	  raise ZipEntryExistsError, 
	    procedureName+" failed. Entry #{entryName} already exists"
	end
      end
    end

    def write_file(entry, destPath, continueOnExistsProc = proc { false })
      if File.exist?(destPath) && ! yield(entry, destPath)
	raise ZipDestinationFileExistsError,
	  "Destination '#{destPath}' already exists"
      end
      File.open(destPath, "wb") { 
	  |os|
	  entry.get_input_stream { |is| os << is.read }
	}
    end
    
    def check_file(path)
      unless File.readable? path
	raise Errno::ENOENT, path
      end
    end
    
    def on_success_replace(aFilename)
      tmpfile = get_tempfile
      tmpFilename = tmpfile.path
      tmpfile.close
      if yield tmpFilename
	FileUtils.mv(tmpFilename, name)
      end
    end
    
    def get_tempfile
      tempFile = Rant::Tempfile.new(File.basename(name), File.dirname(name))
      tempFile.binmode
      tempFile
    end
    
  end

  class ZipStreamableFile < DelegateClass(ZipEntry) #:nodoc:all
    def initialize(entry, filepath)
      super(entry)
      @delegate = entry
      @filepath = filepath
    end

    def get_input_stream(&aProc)
      File.open(@filepath, "rb", &aProc)
    end
    
    def write_to_zip_output_stream(aZipOutputStream)
      aZipOutputStream.put_next_entry(self)
      aZipOutputStream << get_input_stream { |is| is.read }
    end

    def == (other)
      return false unless other.class == ZipStreamableFile
      @filepath == other.filepath && super(other.delegate)
    end

    protected
    attr_reader :filepath, :delegate
  end

  class ZipStreamableDirectory < DelegateClass(ZipEntry) #:nodoc:all
    def initialize(entry)
      super(entry)
    end

    def get_input_stream(&aProc)
      return yield(NullInputStream.instance) if block_given?
      NullInputStream.instance
    end
    
    def write_to_zip_output_stream(aZipOutputStream)
      aZipOutputStream.put_next_entry(self)
    end
  end

  class ZipStreamableStream < DelegateClass(ZipEntry) #nodoc:all
    def initialize(entry)
      super(entry)
      @tempFile = Rant::Tempfile.new(File.basename(name), File.dirname(zipfile))
      @tempFile.binmode
    end

    def get_output_stream
      if block_given?
        begin
          yield(@tempFile)
        ensure
          @tempFile.close
        end
      else
        @tempFile
      end
    end

    def get_input_stream
      if ! @tempFile.closed?
        raise StandardError, "cannot open entry for reading while its open for writing - #{name}"
      end
      @tempFile.open # reopens tempfile from top
      if block_given?
        begin
          yield(@tempFile)
        ensure
          @tempFile.close
        end
      else
        @tempFile
      end
    end
    
    def write_to_zip_output_stream(aZipOutputStream)
      aZipOutputStream.put_next_entry(self)
      aZipOutputStream << get_input_stream { |is| is.read }
    end
  end

  class ZipExtraField < Hash
    ID_MAP = {}

    # Meta class for extra fields
    class Generic
      def self.register_map
        if self.const_defined?(:HEADER_ID)
          ID_MAP[self.const_get(:HEADER_ID)] = self
        end
      end

      def self.name
        self.to_s.split("::")[-1]
      end

      # return field [size, content] or false
      def initial_parse(binstr)
        if ! binstr
          # If nil, start with empty.
          return false
        elsif binstr[0,2] != self.class.const_get(:HEADER_ID)
          $stderr.puts "Warning: weired extra feild header ID. skip parsing"
          return false
        end
        [binstr[2,2].unpack("v")[0], binstr[4..-1]]
      end

      def ==(other)
        self.class != other.class and return false
        each { |k, v|
          v != other[k] and return false
        }
        true
      end

      def to_local_bin
        s = pack_for_local
        self.class.const_get(:HEADER_ID) + [s.length].pack("v") + s
      end

      def to_c_dir_bin
        s = pack_for_c_dir
        self.class.const_get(:HEADER_ID) + [s.length].pack("v") + s
      end
    end

    # Info-ZIP Additional timestamp field
    class UniversalTime < Generic
      HEADER_ID = "UT"
      register_map

      def initialize(binstr = nil)
        @ctime = nil
        @mtime = nil
        @atime = nil
        @flag  = nil
        binstr and merge(binstr)
      end
      attr_accessor :atime, :ctime, :mtime, :flag

      def merge(binstr)
        binstr == "" and return
        size, content = initial_parse(binstr)
        size or return
        @flag, mtime, atime, ctime = content.unpack("CVVV")
        mtime and @mtime ||= Time.at(mtime)
        atime and @atime ||= Time.at(atime)
        ctime and @ctime ||= Time.at(ctime)
      end

      def ==(other)
        @mtime == other.mtime &&
        @atime == other.atime &&
        @ctime == other.ctime
      end

      def pack_for_local
        s = [@flag].pack("C")
        @flag & 1 != 0 and s << [@mtime.to_i].pack("V")
        @flag & 2 != 0 and s << [@atime.to_i].pack("V")
        @flag & 4 != 0 and s << [@ctime.to_i].pack("V")
        s
      end

      def pack_for_c_dir
        s = [@flag].pack("C")
        @flag & 1 == 1 and s << [@mtime.to_i].pack("V")
        s
      end
    end

    # Info-ZIP Extra for UNIX uid/gid
    class IUnix < Generic
      HEADER_ID = "Ux"
      register_map

      def initialize(binstr = nil)
        @uid = 0
        @gid = 0
        binstr and merge(binstr)
      end
      attr_accessor :uid, :gid

      def merge(binstr)
        binstr == "" and return
        size, content = initial_parse(binstr)
        # size: 0 for central direcotry. 4 for local header
        return if(! size || size == 0)
        uid, gid = content.unpack("vv")
        @uid ||= uid
        @gid ||= gid
      end

      def ==(other)
        @uid == other.uid &&
        @gid == other.gid
      end

      def pack_for_local
        [@uid, @gid].pack("vv")
      end

      def pack_for_c_dir
        ""
      end
    end

    ## start main of ZipExtraField < Hash
    def initialize(binstr = nil)
      binstr and merge(binstr)
    end

    def merge(binstr)
      binstr == "" and return
      i = 0 
      while i < binstr.length
        id = binstr[i,2]
        len = binstr[i+2,2].to_s.unpack("v")[0] 
        if id && ID_MAP.member?(id)
          field_name = ID_MAP[id].name
          if self.member?(field_name)
            self[field_name].mergea(binstr[i, len+4])
          else
            field_obj = ID_MAP[id].new(binstr[i, len+4])
            self[field_name] = field_obj
          end
        elsif id
          unless self["Unknown"]
            s = ""
            class << s
              alias_method :to_c_dir_bin, :to_s
              alias_method :to_local_bin, :to_s
            end
            self["Unknown"] = s
          end
          if ! len || len+4 > binstr[i..-1].length
            self["Unknown"] << binstr[i..-1]
            break;
          end
          self["Unknown"] << binstr[i, len+4]
        end
        i += len+4
      end
    end

    def create(name)
      field_class = nil
      ID_MAP.each { |id, klass|
        if klass.name == name
          field_class = klass
          break
        end
      }
      if ! field_class
	raise ZipError, "Unknown extra field '#{name}'"
      end
      self[name] = field_class.new()
    end

    def to_local_bin
      s = ""
      each { |k, v|
        s << v.to_local_bin
      }
      s
    end
    alias :to_s :to_local_bin

    def to_c_dir_bin
      s = ""
      each { |k, v|
        s << v.to_c_dir_bin
      }
      s
    end

    def c_dir_length
      to_c_dir_bin.length
    end
    def local_length
      to_local_bin.length
    end
    alias :c_dir_size :c_dir_length
    alias :local_size :local_length
    alias :length     :local_length
    alias :size       :local_length
  end # end ZipExtraField

end # Zip namespace module



# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
