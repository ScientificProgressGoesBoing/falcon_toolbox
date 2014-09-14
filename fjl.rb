#This ruby script shows a list of all falcon FEL jump labels already used
#Adjust path 'param' as needed
#To be used with .fcv, .ipa, and .tmpl files

#Requires ruby installation 1.9.3 or above
#Execute with
#ruby show_jl.rb
#************************************************************************

#TODO: findet die nach #+I noch nicht !!!
#TODO: loop für unterverlinkte apf-files
#todo: apf files verlinkt aus ... anzeigen
#TODO: unmatched labels
#TODO: Sprungziel unklar
#TODO: Sprungziel liegt nicht innerhalb derselben Unterroutine

require 'pry'

class File_chooser
  
  def initialize
    @path = 'param'
  end

  def file_list_generator
    path = @path
    file_list = []
    Dir["#{path}/*.fcv"].each do |file|
     file_list << file.to_s
    end

    Dir["#{path}/*.tmpl"].each do |file|
      file_list << file.to_s
    end
    
    Dir["#{path}/*.ipa"].each do |file|
      file_list << file.to_s
    end
    
    Dir["#{path}/*.apf"].each do |file|
      file_list << file.to_s
    end
    
    file_list
  end
  
  def file_choice_suggester
    file_list = file_list_generator
    if file_list.count > 0
      file_list.each_with_index do |file, index|
        puts index.to_s + ' ' + file
      end
    else 
      puts 'Neither .fcv nor .tmpl nor .ipa files in directory.'  
    end
    file_list
  end
  
  def cookie_writer(text)
    target_file = open('Cookie.txt', 'w')
    target_file.write text
    target_file.close
  end
  
  def file_choice_reader
    unless File.exists? 'Cookie.txt'
      file_list = file_choice_suggester
      puts 'Choose file by typing index number!'
      chosen_file = gets.chomp
      if /[^0-9]/.match(chosen_file) || chosen_file.to_i >= file_list.count
        abort ('No valid index number.')
      else 
        chosen_file = chosen_file.to_i
      end
      cookie_writer(  file_list[chosen_file].to_s )
      puts 'You chose file: ' + file_list[chosen_file].to_s
      path_and_file = file_list[chosen_file].to_s
    else
      puts '* Change file by typing command: del Cookie.txt *'  
      pre_chosen_file = File.read('Cookie.txt')
      path_and_file = pre_chosen_file.chomp.to_s
    end
    path_and_file
  end    
  
  def cookie_destroyer
    # totally unnecessary, 'del Cookie.txt' is way handier!
  end
 
end


class File_name_and_contents

  attr_reader :path_and_file, :contents

  def initialize(path_and_file)
    @path_and_file = path_and_file
    @contents = File.readlines(path_and_file)
  end

end


class Show_jl

  attr_reader :file_name_and_contents
  
  def initialize
    @file_name_and_contents = File_name_and_contents.new( File_chooser.new.file_choice_reader )
    # @path = @path_and_file.sub(/\/.+/, '')
    # @file = @path_and_file.sub(/.+\//, '')
    # find_jl
  end 
  
  # constants
  ABC = [ 'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z'  ] 
  NUM = [  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9'  ]
  SYMBOL = [ '!', '"', '$', '%', '&', '/', '@', '=', '.', ',', ':', ';'  ]
  # JL = ABC + ABC.map {|letter| letter.downcase } + NUM + SYMBOL
  JL = ABC + NUM + SYMBOL
  
  #returns apf file names
  #method used in all_apf_finder
  def find_apf( path_and_file = self.file_name_and_contents.path_and_file)
    match_apf = []
    regexp = /^t([^ \#]+)( *$|  )/
    File_name_and_contents.new( path_and_file ).contents.each do |line|
      if line.match(regexp) != nil
        if line.match(regexp)[1] != nil 
          match_apf << ( self.file_name_and_contents.path_and_file.sub(/\/.+/, '') + '/' + line.match(regexp)[1].chomp + '.apf' ) 
        end
      end
    end
    match_apf
  end

  #recursive method that returns all apf file names
  def all_apf_finder( path_and_file = self.file_name_and_contents.path_and_file, all_apf_arr = [] )
    apf_files = find_apf( path_and_file )
    if apf_files.count > 0
      all_apf_arr << apf_files
      apf_files.each do |apf_file|
        if File.exists? apf_file
          path_and_file = apf_file
          all_apf_finder( path_and_file, all_apf_arr )
        else
          puts 'Warning: File is linked to but does not exist: ' + apf_file
        end
      end
    end
    all_apf_arr
  end
  
  def file_and_all_apf_names_and_contents_arr
    arr = all_apf_finder
    arr.unshift self.file_name_and_contents.path_and_file
    arr = arr.flatten
    file_and_all_apf_names_and_contents_arr = []
    arr.each do |path_and_file|
      if File.exists? path_and_file
        file_and_all_apf_names_and_contents_arr << File_name_and_contents.new(  path_and_file  )
      end
    end
    file_and_all_apf_names_and_contents_arr
  end
  
  def find_jl
    all_file_names_and_contents = 
    file_names = file_names_and_contents_arr[0]
    if file_names.count > 0 
      contents = file_names_and_contents_arr[1]
      md_arr_all_files = []
      j = 0
      contents.each_with_index do |file_content, index|
        md_arr = []
        file_content.each do |str|
          found = str.scan(/ \+[#]?[^\+ #-]+/).uniq
          md_arr << found unless found.empty?
        end          
        if md_arr.empty?
          puts 'No jump labels found in ' + file_names[index] + '.'
          return 0
        else 
          puts 'Jump labels in file ' + file_names[index] + ':'
          jump_labels = Array.new
          md_arr.each do |m|
            jump_labels.push( m[0].gsub(/^ \+/,'') ) unless m[0] == nil
          end
          jump_labels.uniq.sort.each_with_index do |jl, index|
            puts jl
          end
          #puts "Total in #{file_names[index]}: " + jump_labels.uniq.count.to_s + "\n" + "\n"
          puts "Total: " + jump_labels.uniq.count.to_s + "\n" + "\n"
          j += jump_labels.uniq.count
          md_arr_all_files += md_arr
        end
      end
      # Gesamtanzeige aller jump labels, Gesamtcount
      if file_names.count > 1 && j > 0
        puts 'Jump labels in ALL files:'
        md_arr_all_files.uniq.sort.each do |jl_all_files|
          jl = jl_all_files[0]
          puts jl.sub!(/^[^+]\+/, '')
        end
        puts 'Total: ' + md_arr_all_files.uniq.count.to_s
      end
      # Free jump labels
      if md_arr_all_files.uniq.count > 0
        free_jl = JL - md_arr_all_files.uniq.flatten
        puts "\n" + 'FREE jump labels: ' 
        free_jl.each do |jl|
          print jl
          print '  '
        end
        puts "\n" + 'Total: ' + free_jl.count.to_s + "\n"
      end
    end
    j > 0 ? 1 : 0
  end
    
end #class end

# main
# moved to main.rb





