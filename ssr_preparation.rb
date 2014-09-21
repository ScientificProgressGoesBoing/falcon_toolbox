#This ruby script shows a list of falcon FEL subroutines in use
#Adjust path 'param' as needed
#To be used with .fcv, .ipa, and .tmpl files

#Requires ruby installation 1.9.3 or above
#Execute with
#ruby swr.rb
#************************************************************************

#subroutines liegen nur in der Hauptdatei
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

class Search_arr

  attr_reader :file_name_and_contents
  
  def initialize
    @file_name_and_contents = File_name_and_contents.new( File_chooser.new.file_choice_reader )
  end

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
  
end #class
 

class Show_sr

  attr_reader :search_arr
  
  def initialize
    @search_arr = Search_arr.new.file_and_all_apf_names_and_contents_arr
  end 
  
  def find_sr
    sr_jump_in_regex     = /[^ ]{1} >([a-z]{1})(  | $|$)/
    sr_start_regex       = /^#\(([a-z]{1})(  | $|$)/
    sr_end_regex         = /^#\)([a-z]{1})(  | $|$)/
    conversion_end_regex = /^#\+#(  | $|$)/
    sr_jump_in_hash = {}
    sr_start_found_hash = {}
    sr_end_found_hash = {}
    conversion_end_line = 0
    warnings = []
    #scan for end of conversion
    self.search_arr[0].contents.each_with_index do |line, index|    
      conversion_end_found = line.scan( conversion_end_regex ).uniq.flatten
      conversion_end_line = index + 1 unless conversion_end_found.empty?
    end
    #scan for subroutines
    self.search_arr.each_with_index do |object, ix|  
      file = object.path_and_file
      object.contents.each_with_index do |line, index|
       
        sr_jump_in = line.scan( sr_jump_in_regex ).flatten
        unless sr_jump_in.empty?
          if sr_jump_in_hash[file]
            sr_jump_in_hash[file].push sr_jump_in[0] 
          else
          sr_jump_in_hash[file] = [ sr_jump_in[0] ]
          end
        end
       
        sr_start_found = line.scan( sr_start_regex ).flatten
        unless sr_start_found.empty?
          if file.end_with?( '.tmpl', '.fcv', '.ipa' )  && ( index < conversion_end_line )
            warnings << 'Warning: Definition of subroutine ' + sr_start_found[0].to_s + ' starts before the end of conversion #+#.'
          end
          if file.end_with?('.apf')
            warnings << 'Warning: Subroutine defined in "' + file + '" instead of main file.'
          else
            if sr_start_found_hash[file]
              sr_start_found_hash[file].push sr_start_found[0]
            else
              sr_start_found_hash[file] = [ sr_start_found[0] ]
            end
          end
        end
        
        sr_end_found = line.scan( sr_end_regex ).flatten
        unless sr_end_found.empty? 
          if sr_end_found_hash[file]
            sr_end_found_hash[file].push sr_end_found[0]
          else
            sr_end_found_hash[file] = [ sr_end_found[0] ]
          end
        end
        
      end #end object.contents.each_with_index do |line, index|
    end #end file_and_all_apf_names_and_contents_arr.each_with_index do |object, ix|  
   
    #check
    subroutines = []
    sr_start_found_hash.each do |file, arr|
      arr.each do |element|
        unless sr_end_found_hash.values.flatten.include? element
          warnings << 'Warning: Subroutine ' + element + ' is not closed.'
        else
          subroutines << element
        end
        unless sr_jump_in_hash.values.flatten.include? element
          warnings << 'Subroutine ' + element + ' is not used.'
        end
      end 
    end
    
    sr_jump_in_hash.each do |file, arr|
      arr.each do |element|
       unless sr_start_found_hash.values.flatten.include? element
          warnings << 'Warning: No subroutine ' + element + ' despite >' + element + ' in "' + file +'".'
        end
      end
    end
  
    #output
    puts '' #for readability
    sr_start_found_hash.each do |file, arr|
      puts 'Subroutines implemented in file "' + file + '":'
      puts arr.sort.join(', ')
    end
    puts '' #for readability
    puts warnings.uniq.sort.join("\n")       
  end #method end
      
end #class end

# main
a = Show_sr.new
a.find_sr