#This ruby script shows a list of all falcon FEL jump labels already used
#Adjust path 'param' as needed
#To be used with .fcv, .ipa, and .tmpl files

#Requires ruby installation 1.9.3 or above
#Execute with
#ruby sjl.rb
#************************************************************************

#TODO: findet die nach #+I noch nicht !!!
#todo: apf files verlinkt aus ... anzeigen
#TODO: Sprungziel liegt nicht innerhalb derselben Unterroutine
#      oder im selben Nachladevorgang!


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
    scan_regex = /( |^#)\+([#]?[^\+ #-]+)([^#]|$)/
    target_regex = /^(#-[^+ #]+($| ))|^(#[^+ #]+($| ))/
    all_files_names_and_contents_arr = file_and_all_apf_names_and_contents_arr
    md_arr_all_files = []
    target_arr_all_files = []
    target_arr_all_files << []
    target_arr_all_files << []
    j = 0   #count all jump labels (including duplicates)
    puts '' #for better readability
    #scan all files
    all_files_names_and_contents_arr.each do |object|
      md_arr = []
      target_arr = []
      target_arr << []
      target_arr << []      
      #scan jump labels
      object.contents.each do |line|
         found = line.scan( scan_regex ).uniq.flatten
         md_arr << found[1] unless found.empty?
         #scan targets
         target = line.scan( target_regex ).uniq.flatten
         #target type #-A
         target_arr[0] << target[0] unless ( target.empty? || target[0] == nil )
         #target type field
         target_arr[1] << target[2] unless ( target.empty? || target[2] == nil )
      end
      #targets
      unless target_arr[0].empty?
        target_arr_all_files[0] << target_arr[0]
      end
      unless target_arr[1].empty?
        target_arr_all_files[1] << target_arr[1]
      end
      #output to commandline
      if md_arr.empty?
        puts 'No jump labels found in ' + object.path_and_file + '.'
      else       
        md_arr = md_arr.map {|element| element.chomp}
        md_arr.delete('#')
        #output
        puts 'Jump labels in file ' + object.path_and_file + ':'
        md_arr.uniq.sort.each do |jl|
          puts jl
        end
        puts "Total: " + md_arr.uniq.count.to_s + "\n" + "\n"
        j += md_arr.uniq.count
        md_arr_all_files += md_arr
      end      
    end
    #Gesamtanzeige aller jump labels, Gesamtcount
    if j > 0
      #targets
      target_arr_all_files[0] = target_arr_all_files[0].flatten.map {|element| element.chomp}
      target_arr_all_files[1] = target_arr_all_files[1].flatten.map {|element| element.chomp}
      no_target_warning = ''
      #output jl
      puts "\n~~~"
      puts 'Summary (all files):'
      md_arr_all_files.uniq.sort.each do |jl_all_files|
        puts jl_all_files
        #check matching target exists
        possible_target_form = '#-' + jl_all_files
        unless target_arr_all_files[1].find { |e| /#{jl_all_files}/ =~ e } ||       #type field
               target_arr_all_files[0].find { |e| /#{possible_target_form}/ =~ e }  #type #-A
        no_target_warning += 'Warning: No target exists for +' + jl_all_files + "\n"
        end
      end
      puts 'Total: ' + md_arr_all_files.uniq.count.to_s     
      #not unique targets
      duplicates = target_arr_all_files[0].group_by{|e| e}.keep_if{|_, e| e.length > 1}
      puts "\n" if duplicates.count > 0 || no_target_warning != ''                  #for readability
      if duplicates.count > 0
        # puts 'Warning: Not unique target(s) ' + duplicates.keys.join('  ')
        print 'Warning: Targets not unique ' 
        duplicates.keys.each_with_index do |duplicate, index|
          print duplicate + ' (' + duplicates[duplicate].count.to_s + ')'
          if index < duplicates.count - 1
            print ', ' 
          else 
            print "\n"
          end
        end
      end
      #unmatched jl
      puts no_target_warning if no_target_warning != ''
    end
    #free jump labels
    if j > 0
      free_jl = JL - md_arr_all_files.uniq
      puts "\n~~~"
      puts "\n" + 'FREE jump labels: ' 
      free_jl.each do |jl|
        print jl
        print '  '
      end
      puts "\n" + 'Total free: ' + free_jl.count.to_s + "\n"
    end
    j > 0 ? 1 : 0
  end
end #class end

# main
a = Show_jl.new
a.find_jl





