#This ruby script shows a deduplicated list of all falcon FEL variables currently in use
#Adjust path 'param' as needed
#To be used with .fcv, .ipa and .tmpl files

#Requires ruby installation 1.9.3 or above
#Execute with
#ruby show_var.rb

path = 'param'


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
  
  
class Show_var

  attr_reader :search_arr
  
  def initialize
    @search_arr = Search_arr.new.file_and_all_apf_names_and_contents_arr
  end 
  
  def delete_comments( line )
    line = line.gsub(/\/\/.*$|  .*$/, '')
  end
  
  def search_for_variables
    variable_regex = / [aA=]{1}([a-z]{1}[a-z0-9]{1})(  | $|$)/
    var_found_hash = {}   
    self.search_arr.each do |object|  
    file = object.path_and_file
      object.contents.each do |line|
        line = delete_comments( line )
        var_found = line.scan( variable_regex ).flatten
        unless var_found.empty?
          if var_found_hash[file]
            var_found_hash[file].push var_found[0] 
          else
            var_found_hash[file] = [ var_found[0] ]
          end
        end
      end
    end
    var_found_hash
  end          
  
  def is_deleted? ( variable )
    del_regex = / (d[~#{variable[0]}]{1}[~#{variable[1]}]{1})( |$)/
    self.search_arr.each do |object|
      object.contents.each do |line|
        del_found = delete_comments( line ).scan( del_regex ).flatten[0]
        if del_found != nil
          return true
        end
      end
    end
    return false
  end
  
  def find_var
    var_found_hash = self.search_for_variables
    total_variable_count = var_found_hash.values.flatten.uniq.count  
    if var_found_hash.count > 1
      puts '' #for readability
      puts 'Summary (all files): '
      var_found_hash.values.flatten.uniq.sort.each do |variable|
        puts variable
      end
      puts 'Total: ' + total_variable_count.to_s + "\t" + '(in ' + var_found_hash.values.flatten.count.to_s + ' individual occurences)'
    end  
    #output      
    puts '' #for readability
    var_found_hash.each do |file, arr|
      puts 'Variables in file "' + file + '":'
      puts arr.uniq.sort.join(', ')
      puts 'Total: ' + arr.uniq.count.to_s + "\t" + '(in ' + arr.count.to_s + ' individual occurences)'
      puts '' #for readability      
    end    
    #check if deleted
    var_found_hash.values.flatten.uniq.sort.each do |variable|
      deleted = self.is_deleted?( variable )
      unless deleted
        puts 'Warning: Variable ' + variable + ' is never deleted.' 
      end
    end
    #free variables
    puts 'Remaining free variables: ' + ( 936 - total_variable_count ).to_s
  end 
    
end #class end


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
    self.search_arr.each do |object|  
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


class Show_jl

attr_reader :search_arr
  
def initialize
  @search_arr = Search_arr.new.file_and_all_apf_names_and_contents_arr
end
  
  # constants
  ABC = [ 'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z'  ] 
  NUM = [  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9'  ]
  SYMBOL = [ '!', '"', '$', '%', '&', '/', '@', '=', '.', ',', ':', ';'  ]
  # JL = ABC + ABC.map {|letter| letter.downcase } + NUM + SYMBOL
  JL = ABC + NUM + SYMBOL
  
  def find_jl
    scan_regex = /( |^#)\+([#]?[^\+ #-]+)([^#]|$)/
    target_regex = /^(#-[^+ #]+($| ))|^(#[^+ #]+($| ))/
    md_arr_all_files = []
    target_arr_all_files = []
    target_arr_all_files << []
    target_arr_all_files << []
    j = 0   #count all jump labels (including duplicates)
    puts '' #for better readability
    #scan all files
    self.search_arr.each do |object|
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
if ARGV.include?( '-var' )
Show_var.new.find_var
end

if ARGV.include?( '-sr' )
Show_sr.new.find_sr
end

if ARGV.include?( '-jl' )
Show_jl.new.find_jl
end


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#TODO: count "=" as deleting a variable