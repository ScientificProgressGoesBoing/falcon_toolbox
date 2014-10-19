#v.0.2.3
#This version does not yet include comparison of indicators. 
#Requires Ruby 1.9.3 or higher

require 'time'
require 'etc' ##platform independent getlogin ##works but not used

class Compare_file_chooser

  attr_reader :files, :choice

  def initialize
    @files = Stat_file_reader.new.stat_file_list_generator
    @choice = self.choice_maker
  end
  
  def choice_suggester
    self.files.each_with_index do |file, index|
      puts index.to_s + "\t" + file     
    end
  end
  
  def choice_maker
    abort('No stat file in directory.') if self.files.count == 0
    abort('Only one stat file in directory.') if self.files.count == 1
    puts 'Which file is the base for comparison (old file)?'
    self.choice_suggester
    base_file = gets.chomp
    if /[^0-9]/.match(base_file) || base_file.to_i >= self.files.count
      abort ('No valid index number.')
    end 
    #TODO: More than one file as basis for comparison?
    puts 'Which file is new?'
    self.choice_suggester
    compare_file = gets.chomp
    if /[^0-9]/.match(compare_file) || compare_file.to_i >= self.files.count
      abort ('No valid index number.')
    end 
    chosen_files = {  'base_file' => base_file, 'compare_file' => compare_file }
    text = 'Compared stat files' + " on " +  Time.now.to_s[0..18] + "\n" + 'Base file: ' + base_file + "\n" + 'Compare file: ' + compare_file + "\n\n"
    self.log_writer( text )
    chosen_files
  end

  def log_writer( text )
    filename = 'cfstat.log'
    if File.exists? filename
      log_file = open(filename, 'a')
    else
      log_file = open(filename, 'w')
    end
      log_file.write text
      log_file.close
  end

end #class end


class File_name_and_contents

  attr_reader :path_and_file, :contents

  def initialize(path_and_file)
    @path_and_file = path_and_file
    @contents = File.readlines(path_and_file)
  end

end #class end


class Tag_reader

  attr_reader :path_and_file, :contents

  def initialize(file_names_and_contents)
    @path_and_file = file_names_and_contents.path_and_file
    @contents = file_names_and_contents.contents
  end
  
  def read_tags
    #prepare hashes because of validity outside loop
    all_hash = {}
    tag = nil
    inner_hash = {}
    subfield_hash = {}
    #loop
    self.contents.each do |line|
      #scan lines
      #if line with field
      if line.match(/^#[^\s*]+\s+(\d+)\s+(\d+)/)      
        if tag != nil #every time after the first, tag has still value of last loop
          hash = { tag => inner_hash }
          all_hash = all_hash.merge( {tag => hash} )
        end      
        #reset because new field
        subfield_hash = {}
        inner_hash = {}
        #new
        tag = line.match(/^#.{3}/).to_s     
        occurence = line.match(/^#[^\s*]+\s+(\d+)\s+/)[1].to_i
        max_occurrence = line.match(/^#[^\s*]+\s+(\d+)\s+(\d+)/)[2].to_i
        inner_hash1 = { 'occurrence' => occurence }
        inner_hash2 = { 'max_occurrence' => max_occurrence }    
        inner_hash = inner_hash1.merge( inner_hash2 )
        #merge result
        hash = { tag => inner_hash }
        all_hash = all_hash.merge( {tag => hash} )
      #if line with subfield
      elsif line.match(/^ \$[^ #\$]{1}\s+(\d+)\s+(\d+)/)
        subfield_tag = line.match(/^ \$([^ #\$]{1})/)[1].to_s
        subfield_occurrence = line.match(/^ \$[^ #\$]{1}\s+(\d+)\s+(\d+)/)[1].to_i
        subfield_max_occurrence = line.match(/^ \$[^ #\$]{1}\s+(\d+)\s+(\d+)/)[2].to_i
        inner_hash3 = { 'subfield_occurrence' => subfield_occurrence }
        inner_hash4 = { 'subfield_max_occurrence' => subfield_max_occurrence }
        inner_subfield_hash = inner_hash3.merge( inner_hash4 )
        subfield_hash = { subfield_tag => inner_subfield_hash }
      elsif line.match(/^ind-1/)
          #???
      elsif line.match(/^ind-2/)
          #???
      end
      #collect
      if subfield_hash != nil
        inner_hash = inner_hash.merge( subfield_hash )
      end
    end #end loop
    hash = { tag => inner_hash }
    all_hash = all_hash.merge( {tag => hash} )
    all_hash
  end
  
  def print_stat_hash
    self.read_tags.each do |hash|
      hash #TODO
    end
  end

end  #class end

 
class Stat_file_reader

  attr_accessor :stat_file_list

  def initialize
    @stat_file_list
  end

  def stat_file_list_generator
    path = @path
    self.stat_file_list = []
    Dir["*/StatLong"].each do |file|
     self.stat_file_list << file.to_s
    end
    self.stat_file_list
  end
  
  def file_list_to_objects
    stat_file_list = self.stat_file_list_generator
    file_names_and_contents_arr = []
    stat_file_list.each do |stat_file|
      file_names_and_contents_arr << File_name_and_contents.new(stat_file)
    end
    file_names_and_contents_arr
  end
  
  def load_stat_files
    stat_names_and_contents = self.file_list_to_objects
    stat_names_and_contents.each do |object|
      StatLong.new(object).read_tags
    end
  end
  
  def each(&block)
      self.stat_file_list_generator.each do |file|
        block.call file
      end
  end

end


class Compare

  attr_reader :stat_base, :stat_to_compare, :choice

  def initialize
    @choice = Compare_file_chooser.new.choice
    @stat_base = Tag_reader.new( Stat_file_reader.new.file_list_to_objects[ self.choice['base_file'].to_i ] ).read_tags   
    @stat_to_compare = Tag_reader.new( Stat_file_reader.new.file_list_to_objects[ self.choice['compare_file'].to_i ] ).read_tags   
  end
  
  def do
    new_fields = []
    omitted_fields = []
    count_differs = []
    max_count_differs = []
    self.stat_base.each do |tag, hash|
      ######
      #field
      unless self.stat_to_compare.include?( tag )
        omitted_fields << tag 
      else 
        #compare field count
        unless self.stat_base[tag][tag]['occurrence'] == self.stat_to_compare[tag][tag]['occurrence']
          count_differs << tag
        end
        unless self.stat_base[tag][tag]['max_occurrence'] == self.stat_to_compare[tag][tag]['max_occurrence']
          max_count_differs << tag
        end
        self.stat_base[tag][tag].each do |subtag, value|
          if subtag.length == 1
            ##########
            #subfields          
            unless self.stat_to_compare[tag][tag].include? subtag
              omitted_fields << tag + '$' + subtag
            else
              #compare subfield count
              unless self.stat_base[tag][tag][subtag]['subfield_occurrence'] == self.stat_to_compare[tag][tag][subtag]['subfield_occurrence']
                count_differs << tag + '$' + subtag 
              end
              unless self.stat_base[tag][tag][subtag]['subfield_max_occurrence'] == self.stat_to_compare[tag][tag][subtag]['subfield_max_occurrence']
                max_count_differs << tag + '$' + subtag
              end
            end
          end
        end  
      end     
    end
    self.stat_to_compare.each do |tag, hash|
      ######
      #field
      unless self.stat_base.include?( tag )
        new_fields << tag 
      else
        self.stat_to_compare[tag][tag].each do |subtag, value|
          if subtag.length == 1
            ##########
            #subfields
            unless self.stat_base[tag][tag].include?( subtag )
              new_fields << tag + '$' + subtag
            end
          end
        end
      end
    end
    {
      'new_fields' => new_fields,
      'omitted_fields' => omitted_fields,
      'count_differs' => count_differs,
      'max_count_differs' => max_count_differs
    }
  end  #method end
  
  def to_s
    # output to screen
    result = self.do
    base_file = Stat_file_reader.new.file_list_to_objects[ self.choice['base_file'].to_i ].path_and_file
    compare_file = Stat_file_reader.new.file_list_to_objects[ self.choice['compare_file'].to_i ].path_and_file
    puts ''
    puts 'Stat comparison'
    puts ''
    puts 'Base file: ' + "\t" + base_file
    puts 'Compared file: ' + "\t" + compare_file
    puts ''
    unless result['new_fields'].empty?
      puts 'New fields and subfields in ' + compare_file + ':'
      puts result['new_fields'].sort 
    else
      puts 'No new fields or subfields.'
    end
    unless result['omitted_fields'].empty?
      puts ''
      puts 'Omitted fields that no longer exist in ' + compare_file + ':' 
      puts result['omitted_fields'] unless result['omitted_fields'].empty?
      puts ''
    else
      puts 'No omitted fields or subfields.' 
    end
    unless result['count_differs'].empty?
      puts 'Field occurrence differs in the following fields and subfields (base count, compare count, difference):' 
      puts ''
      result['count_differs'].sort.each do |item|
        if item.scan(/\$/).empty?
          #field
          puts item  + "\t" + self.stat_base[item][item]['occurrence'].to_s + "\t" + self.stat_to_compare[item][item]['occurrence'].to_s + "\t\t" + ( self.stat_to_compare[item][item]['occurrence'] - self.stat_base[item][item]['occurrence'] ).to_s
        else
          #subfield
          tag = item.sub(/\$.+/, '')
          subtag = item.sub(/^.+\$/, '')
          puts item  + "\t" + self.stat_base[tag][tag][subtag]['subfield_occurrence'].to_s + "\t" + self.stat_to_compare[tag][tag][subtag]['subfield_occurrence'].to_s + "\t\t" + ( self.stat_to_compare[tag][tag][subtag]['subfield_occurrence'] - self.stat_base[tag][tag][subtag]['subfield_occurrence'] ).to_s
        end
      end
      puts ''
    else
      puts 'No differences in field and subfield count.'
    end
    unless result['max_count_differs'].empty?
      puts 'Max occurence differs in the following fields and subfields (base count, compare count, difference): '
      puts ''
      result['max_count_differs'].sort.each do |item|
        if item.scan(/\$/).empty?
          #field
          puts item  + "\t" + self.stat_base[item][item]['max_occurrence'].to_s + "\t" + self.stat_to_compare[item][item]['max_occurrence'].to_s + "\t\t" + ( self.stat_to_compare[item][item]['max_occurrence'] - self.stat_base[item][item]['max_occurrence'] ).to_s
        else
          #subfield
          tag = item.sub(/\$.+/, '')
          subtag = item.sub(/^.+\$/, '')
          puts item  + "\t" + self.stat_base[tag][tag][subtag]['subfield_max_occurrence'].to_s + "\t" + self.stat_to_compare[tag][tag][subtag]['subfield_max_occurrence'].to_s + "\t\t" + ( self.stat_to_compare[tag][tag][subtag]['subfield_max_occurrence'] - self.stat_base[tag][tag][subtag]['subfield_max_occurrence'] ).to_s
        end
      end
      puts ''
    else 
      puts 'No differences in max occurence of fields and subfields.'
    end
    puts ''
    puts 'Generated on: ' + Time.now.to_s[0..18]
    puts 'Generated by: ' + ENV['USERNAME'] ##Windows
    # puts 'Generated by: ' + Etc.getlogin ##platform independent
    self
  end
  
  def save_to_file
    stdout = $stdout
    base_file = Stat_file_reader.new.file_list_to_objects[ self.choice['base_file'].to_i ].path_and_file
    compare_file = Stat_file_reader.new.file_list_to_objects[ self.choice['compare_file'].to_i ].path_and_file
    base_file_short = base_file.sub(/^.*\$(.+)\/.*/, '\1')
    compare_file_short = compare_file.sub(/^.*\$(.+)\/.*/, '\1')
    # timestamp = Time.now.to_s[0..16].sub(':', 'h') #timestamp caused problems with file name #
    filename = 'cfstat_' + '_' + base_file_short + '_' + compare_file_short + '.csv'
    if File.exists? filename
      puts 'File exists. Rename file and run again.'
    else
      $stdout = File.new(filename, 'w')
      self.to_s
      $stdout = stdout
      puts "File written."
    end
  end

end #class end

  

#main
system 'cls'
Compare.new.to_s.save_to_file
puts ''
puts ''
puts '>>Exit script pressing Enter'
gets