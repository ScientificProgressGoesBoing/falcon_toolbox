#This ruby script shows a deduplicated list of all falcon FEL variables currently in use
#Adjust path 'param' as needed
#To be used with .fcv, .ipa and .tmpl files

#Requires ruby installation 1.9.3 or above
#Execute with
#ruby falcon.rb

#Available options
#-var   list variables
#-sr    list subroutines
#-jl    list jump labels

path = 'param'

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#TODO: count "=" as deleting a variable


class File_chooser

  attr_accessor :hints_hash
  
  def initialize
    @path = 'param'
    @hints_hash = {}
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
      self.hints_hash = hints_hash.merge( 'cookie_del' => '* Change file by typing command: del Cookie.txt *' )
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

  attr_reader :file_name_and_contents, :file_chooser, :file_choice
  attr_accessor :hints_hash
  
  def initialize
    @hints_hash = {}
    @file_chooser = File_chooser.new 
    @file_choice = self.file_chooser.file_choice_reader
    @file_name_and_contents = File_name_and_contents.new( self.file_choice )
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
          if self.hints_hash['file_does_not_exist']
            self.hints_hash['file_does_not_exist'] << apf_file
          else
            self.hints_hash = self.hints_hash.merge( 'file_does_not_exist' => [ apf_file ] )
          end
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


class Search_instruction

  def initialize( regex_hash )
    regex_hash.each do |name, value|
      instance_variable_set("@#{name}", value)
      self.class.send(:attr_reader, name)
    end
  end
  
  def each(&block)
    self.instance_variables.each do |instance_variable|
      block.call instance_variable
    end
  end

end


class Search_instructions_repository

  attr_accessor :sr, :jl #, :var
 
  def initialize
    @sr = Search_instruction.new( { 'sr_jump_in_regex' => /[^ ]{1} >([a-z]{1})( | $|$)/ ,      ##check here ?:
    'sr_start_regex' => /^#\(([a-z]{1})( | $|$)/ ,
    'sr_end_regex' => /^#\)([a-z]{1})( | $|$)/ ,
    'conversion_end_regex' => /^#\+#( | $|$)/ } )
     
    @jl = Search_instruction.new( { 'jl_regex' => /( |^#)\+([#]?[^\+ #-]+)([^#]|$)/ ,
                                     'target_regex' => /^(#-[^+ #]+($| ))|^(#[^+ #]+($| ))/ } )
                                     
    # @var = Search_instruction.new( { 'variable_regex' => / [aA=]{1}([a-z]{1}[a-z0-9]{1})(  | $|$)/ ,
                                     # 'del_regex' => / (d[~#{variable[0]}]{1}[~#{variable[1]}]{1})( |$)/  } )
                                     # 'del_regex' => / (d[~#{variable[0]}]{1}[~#{variable[1]}]{1})( |$)/  } )                                   
  end

   def each(&block)
    self.instance_variables.each do |instance_variable|
      block.call instance_variable
    end
  end
  
end
  
  
class Show_whatever 

attr_reader :search_arr, :search_instructions_repository
  
  def initialize
    @search_arr = Search_arr.new.file_and_all_apf_names_and_contents_arr
    @search_instructions_repository = Search_instructions_repository.new
    # @result_hash = {}
  end 
  
  def delete_comments( line )
    line = line.gsub(/\/\/.*$|  .*$/, '')
  end  
  
  # def iterate( search_instruction )
    # self.search_arr.each do |object|  
      # path_and_file = object.path_and_file
      # object.contents.each do |line|
        # line = line.delete_comments
        # # do something
        # # search_instruction.each do |si_name, si|
          # # line.scan
        # # end
    # end
  # end
  
  def collect( found, pointer, found_hash )
    if found_hash[pointer]
      found_hash[pointer].push found
    else
      found_hash[pointer] = [ found ]
    end
    found_hash
  end
  
  def find( search_instruction )  
    all_found_hash = {}
    #iterate through files
    self.search_arr.each do |object|  
      path_and_file = object.path_and_file
      #iterate through lines
      found_hash = {}
      object.contents.each do |line|
        line = delete_comments( line )
        # p line
        # p line.match(/( |^#)\+([#]?[^\+ #-]+)([^#]|$)/)
      
        #use all regexes on each line        
        self.search_instructions_repository.send( search_instruction ).each do |name_of_instruction|
          name_of_instruction = name_of_instruction.to_s.sub('@', '')
          regex = self.search_instructions_repository.send( search_instruction ).send( name_of_instruction )
          found = line.scan( regex ).flatten
          unless found.empty?
            p found.each { |found| collect( found, name_of_instruction, found_hash ) }
          end
        end
      end
    end  
  all_found_hash
  end
  
end  

  
class Show_var

  attr_reader :search_arr, :search_arr_object
  
  def initialize
    @search_arr_object = Search_arr.new
    @search_arr = self.search_arr_object.file_and_all_apf_names_and_contents_arr
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
  
  def find
    var_found_hash = self.search_for_variables
    total_distinct_variable_count = var_found_hash.values.flatten.uniq.count  
    total_occurences_variable_count = var_found_hash.values.flatten.count.to_s
    #save for output
    result_hash_var = {}
    result_hash_var = result_hash_var.merge( 'found' => var_found_hash )
    result_hash_var = result_hash_var.merge( 'total_disctinct_count' => total_distinct_variable_count )
    result_hash_var = result_hash_var.merge( 'total_occurences_count' => total_occurences_variable_count )
    #check if deleted
    result_hash_var = result_hash_var.merge( 'warning_not_deleted' => [] )
    var_found_hash.values.flatten.uniq.sort.each do |variable|
      deleted = self.is_deleted?( variable )
      unless deleted
       result_hash_var['warning_not_deleted'] << variable
      end
    end
    #free variables
    result_hash_var = result_hash_var.merge( 'free_count' => ( 936 - total_distinct_variable_count ) )
    result_hash_var
  end 
  
  def output
    result_hash = self.find
    puts '' #for readability
    puts 'Per file: '
    puts ''
    result_hash['found'].each do |file, values|
      puts file.to_s 
      puts values.uniq.sort.join(', ')                     
      puts 'Total: ' + values.uniq.count.to_s
      puts ''
    end
    puts 'Summary: '
    result_hash.each do |key, value|
      unless key == 'found' || key == 'free_count'
        puts key.to_s + "\t" + value.to_s
      end
    end
    puts 'Free variables left' + "\t" + result_hash['free_count'].to_s
    puts ''  #for readability
    self.search_arr_object.hints_hash['file_does_not_exist'].each do |file|
      puts 'Warning! File is linked to but does not exist: ' + file
    end
    puts ''  #for readability
    puts self.search_arr_object.file_chooser.hints_hash.values[0]
  end
  
  def output_warnings
    self.search_arr_object.hints_hash['file_does_not_exist'].each do |file|
      puts 'Warning! File is linked to but does not exist: ' + file
    end
  end
    
end #class end


class Show_sr

  attr_reader :search_arr, :search_arr_object
  
  def initialize
    @search_arr_object = Search_arr.new
    @search_arr = self.search_arr_object.file_and_all_apf_names_and_contents_arr
  end 
  
  def find
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
    
    result_hash = { 
                    'sr_jump_in_hash'      => sr_jump_in_hash,
                    'sr_start_found_hash'  => sr_start_found_hash,
                    'sr_end_found_hash'    => sr_end_found_hash,
                    'conversion_end_line'  => conversion_end_line,
                    'warnings'             => warnings.uniq            
                  }
  end  #end method
    
  def output
    result_hash = self.find
    puts '' #for readability
    result_hash['sr_start_found_hash'].each do |file, arr|
      puts 'Subroutines implemented in file "' + file + '":'
      puts arr.sort.join(', ')
    end
    puts '' #for readability
    puts result_hash['warnings'].uniq.sort.join("\n")    
    #output general warnings 
    puts ''  #for readability
    self.search_arr_object.hints_hash['file_does_not_exist'].each do |file|
      puts 'Warning! File is linked to but does not exist: ' + file
    end
    puts ''  #for readability
    puts self.search_arr_object.file_chooser.hints_hash.values[0]
  end #method end
      
end #class end


class Show_jl

  attr_reader :search_arr, :search_arr_object
    
  def initialize
    @search_arr_object = Search_arr.new
    @search_arr = self.search_arr_object.file_and_all_apf_names_and_contents_arr
  end
  
  # constants
  ABC = [ 'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z'  ] 
  NUM = [  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9'  ]
  SYMBOL = [ '!', '"', '$', '%', '&', '/', '@', '=', '.', ',', ':', ';'  ]
  JL = ABC + ABC.map {|letter| letter.downcase } + NUM + SYMBOL
  
  def find
    jl_regex = /( |^#)\+([#]?[^\+ #-]+)([^#]|$)/
    target_regex = /^(#-[^+ #]+($| ))|^(#[^+ #]+($| ))/
    jl_hash_all_files = {}
    target_hash_all_files = {}
    #scan all files
    self.search_arr.each do |object|     
      file = object.path_and_file
      object.contents.each do |line|
        #scan jump labels
        found = line.scan( jl_regex ).uniq.flatten
        #save found jump labels
        if jl_hash_all_files[file]
          jl_hash_all_files[file] << found[1] unless found.empty?
          jl_hash_all_files[file] = jl_hash_all_files[file].map {|element| element.chomp}  #change place, here it is repeated unnecessarily
        else
          jl_hash_all_files[file] = [ found[1] ] unless found.empty?
        end
        #scan targets
        target = line.scan( target_regex ).uniq.flatten
        if target_hash_all_files[file]
          #target type #-A
          if target_hash_all_files[file]['label']
            target_hash_all_files[file]['label'] << target[0] unless ( target.empty? || target[0] == nil )
          else
            target_hash_all_files[file] = target_hash_all_files[file].merge( { 'label' => [ target[0] ] } ) unless ( target.empty? || target[0] == nil )
          end
          #target type field
          if target_hash_all_files[file]['field']
            target_hash_all_files[file]['field'] << target[2] unless ( target.empty? || target[2] == nil )
          else
          target_hash_all_files[file] = target_hash_all_files[file].merge( { 'field' => [ target[2] ] } ) unless ( target.empty? || target[2] == nil ) 
          end
        else
          #target type #-A
          unless ( target.empty? || target[0] == nil )        
            target_hash_all_files[file] = { 'label' => [ target[0] ] } 
            #target type field
            target_hash_all_files[file] = target_hash_all_files[file].merge( { 'field' => [ target[2] ] } ) unless ( target.empty? || target[2] == nil ) 
          end
          #target type field
          unless ( target.empty? || target[2] == nil ) 
            target_hash_all_files[file] = { 'field' => [ target[2] ] } 
             target_hash_all_files[file] = target_hash_all_files[file].merge( { 'label' => [ target[0] ] } ) unless ( target.empty? || target[0] == nil )    
          end
        end
      end
    end    
    result_hash = {
                    'jl_hash_all_files'      => jl_hash_all_files,
                    'target_hash_all_files'  => target_hash_all_files
                  }
  end
  
  def sort_targets_per_type( result_hash )
    #sort targets
    target_arr_label = []
    target_arr_field = []
    result_hash['target_hash_all_files'].each do |file, hash|
      hash.each do |type, arr|
        arr = arr.map { |element| element.chomp }
        if type == 'label'
          target_arr_label += arr
        elsif type == 'field'
          target_arr_field += arr
        end        
      end    
    end
    sorted_per_type_targets_hash = { 
                            'label' => ( target_arr_label = target_arr_label.sort ),       #not uniq because later check for not uniqe targets
                            'field' => ( target_arr_field = target_arr_field.sort )
                          }  
  end
  
  def check_target_missing( result_hash )
    sorted_per_type_targets_hash = sort_targets_per_type( result_hash )
    #warnings
    warning_target_missing = []
    result_hash['jl_hash_all_files'].each do |file, arr|
      arr.each do |jl|
        #check if matching target exists
        conjectured_target_label = '#-' + jl
        unless  sorted_per_type_targets_hash['label'].uniq.find { |e| /#{conjectured_target_label}/ =~ e } ||  #type #-A
                sorted_per_type_targets_hash['field'].uniq.find { |e| /#{jl}/ =~ e } ||                        #type field            
          warning_target_missing << jl
        end
      end
    end
  warning_target_missing.uniq.sort  
  end #end method
  
  def check_target_not_unique( result_hash )
    sorted_per_type_targets_hash = sort_targets_per_type( result_hash )
    targets_type_label = sorted_per_type_targets_hash['label']
    #warnings
    warning_target_not_unique = []
    duplicates = targets_type_label.group_by{ |e| e }.keep_if{ |_, e| e.length > 1 }
    if duplicates.count > 0
      warning_target_not_unique = duplicates.sort.map { |arr| [ arr[0], arr[1] = arr[1].count ] }
    end
    warning_target_not_unique
  end
  
  def run_checks
    result_hash = self.find
    missing = self.check_target_missing( result_hash )
    duplicates = self.check_target_not_unique( result_hash )
    check_hash = {
                    'missing'     => missing,
                    'duplicates'  => duplicates
                 }
  end
  
  def check_results
    check_results = self.run_checks    
    check_results_worded_out = []
    check_results_worded_out << 'Warning! No target exists for +' + check_results['missing'].join(', ') + '.'
    check_results['duplicates'].each do |duplicate, duplicate_count|
      check_results_worded_out << ( 'Warning! Target not unique: ' + duplicate + ' (' + duplicate_count.to_s + 'x).' )
    end
  end
    
  def output
    result_hash = self.find
    all_jl_arr = []
    total_distinct_count = 0
    total_occurrences_count = 0
    result_hash['jl_hash_all_files'].each do |file, arr|
      if arr.empty?
        puts 'No jump labels found in ' + file + '.'
      else       
        arr = arr.map { |element| element.chomp }
        arr.delete('#')
        puts 'Jump labels in ' + file + ':'
        puts arr.uniq.sort.join(', ')
        puts "Total: " + arr.uniq.count.to_s + "\n" + "\n"
        total_distinct_count += arr.uniq.count
        total_occurrences_count += arr.count
        all_jl_arr += arr
      end      
    end
    #summary    
    if result_hash['jl_hash_all_files'].count > 1 && total_distinct_count > 0
      puts "\n~~~"
      puts 'Summary (all files):'
      puts all_jl_arr.uniq.sort.join(', ')
      puts 'Total: ' + all_jl_arr.uniq.count.to_s   
    end
    #output warnings    
    check_results = self.check_results
    puts ''  #for readability
    check_results.each do |warning|
      puts warning
    end
    #output general warnings
    self.search_arr_object.hints_hash['file_does_not_exist'].each do |file|
      puts 'Warning! File is linked to but does not exist: ' + file
    end
    puts ''  #for readability
    puts self.search_arr_object.file_chooser.hints_hash.values[0]
    #free jump labels
    if total_distinct_count > 0
      free_jl = JL - all_jl_arr.uniq
      puts ''
      puts 'FREE jump labels: ' 
      puts free_jl.join('  ')
      puts 'Total free: ' + free_jl.count.to_s 
    end
  end
  
end #class end


class Get_all_warnings
  
  attr_reader :warnings
  
  def initialize
  @warnings =   {
                  'var'     => Show_var.new.find['warning_not_deleted'],
                  'sr'      => Show_sr.new.find['warnings'],
                  'jl'      => Show_jl.new.check_results,
                  'info' => self.combine_general_warnings
                }
  end
  
  def combine_general_warnings
    combined_general_warnings =   Show_var.new.search_arr_object.file_chooser.hints_hash.values.concat(
                                  Show_sr.new.search_arr_object.file_chooser.hints_hash.values).concat(
                                  Show_jl.new.search_arr_object.file_chooser.hints_hash.values)
                                  .flatten.uniq.sort                           
  end
  
  # self.search_arr_object.hints_hash['file_does_not_exist'].each do |file|
      # puts 'Warning! File is linked to but does not exist: ' + file
    # end
  
  def output_all
    warnings.each do |topic, warning|
        puts topic + ': ' + warning.join(', ')
    end
  end
  
  def output( key )
    self.warnings[key].each do |warning|
      puts warning
    end
  end
  
  def output_except( key )
    warnings = self.warnings.tap {|h| h.delete(key)}
    warnings.each do |topic, warning|
        puts topic + ': ' + warning.join(', ')
    end
  end
  
end


class Help

  def initialize
    self.list_options
  end
  
  def list_options
    puts 'Available options: '
    puts '-var' + "\t" + 'to list Variables'
    puts '-sr' + "\t" + 'to list Subroutines'
    puts '-jl' + "\t" + 'to list Jump Lables'
    puts ''
    puts 'Example: ruby falcon.rb -jl'
    puts '(combination of options is possible)'    
  end
  
end


class Validity_checker

  attr_reader :invalid_arguments
  
  def initialize
    @invalid_arguments = self.check_validity
  end

  def check_validity
    invalid_arguments = []
    valid_arguments = []
    ARGV.each do |argument|
      unless ['-var', '-sr', '-jl'].include? argument                           #register new options HERE!!!
        invalid_arguments << argument
      else
        valid_arguments << argument
      end
    end
    invalid_arguments
  end
  
  def output
    if self.invalid_arguments.count > 0 
      warning = if invalid_arguments.count > 1
                ' aren\'t valid options'
                elsif invalid_arguments.count == 1
                ' is not a valid option'
                end  
      puts invalid_arguments.join(' and ') + warning
      Help.new
    end 
  end
  
end 

#test
# p  a = Show_var.new.search_arr_object.file_chooser.hints_hash
# p Show_var.new.search_arr.file_chooser.file_choice_reader #hints_hash
# Show_whatever.new.find_sr                              
# sr = Search_instruction.new( { 'sr_jump_in_regex' => /[^ ]{1} >([a-z]{1})(  | $|$)/ , 
                                  # 'sr_start_regex' => /^#\(([a-z]{1})(  | $|$)/ , 
                                  # 'sr_end_regex' => /^#\)([a-z]{1})(  | $|$)/ , 
                                  # 'conversion_end_regex' => /^#\+#(  | $|$)/            } )  
# p sr.sr_jump_in_regex                                  
# a = Show_whatever.new
# p a.find( 'jl' )
# a.search_instructions_repository.jl.each do |n|
  # p n
  # n = n.to_s.sub('@', '')
  # p regex = a.search_instructions_repository.jl.send( n )
# end


      
      
# main
if ARGV.count > 0
  Validity_checker.new.output
else
  puts 'What do you want to do?'
  Help.new
end

# if ARGV.count > 1
  # #puts separator
# end

if ARGV.include?( '-var' )
  Show_var.new.output
end

if ARGV.include?( '-sr' )
  Show_sr.new.output
end

if ARGV.include?( '-jl' )
  Show_jl.new.output
end

# Get_all_warnings.new.warnings
# Get_all_warnings.new.output( 'general' )
Get_all_warnings.new.output( 'sr' )
# Get_all_warnings.new.output_except( 'sr' )



