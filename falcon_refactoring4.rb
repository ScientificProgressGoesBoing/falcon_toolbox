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

  attr_reader :sr, :jl, :var

 # def initialize
    # Show_whatever.subclasses.each do |subclass|
      # instance_variable_set("@#{subclass.to_s.downcase}", subclass.new.search_instruction)
      # self.class.send(:attr_reader, subclass.to_s.downcase)
    # end
  # end
 
  def initialize
    @sr = Search_instruction.new( 
                                  { 'sr_jump_in_regex' => /[^ ]{1} >([a-z]{1})( | $|$)/ ,   
                                    'sr_start_regex' => /^#\(([a-z]{1})( | $|$)/ ,
                                    'sr_end_regex' => /^#\)([a-z]{1})( | $|$)/ ,
                                    'conversion_end_regex' => /^#\+#( | $|$)/ 
                                  } 
                                )
     
    @jl = Search_instruction.new( 
                                  { 'jl_regex' => /( |^#)\+([#]?[^\+ #-]+)([^#]|$)/ ,
                                    'target_regex' => /^(#-[^+ #]+($| ))|^(#[^+ #]+($| ))/ 
                                  } 
                                )
                                     
    @var = Search_instruction.new(
                                    { 'variable_regex' => / [aA=]{1}([a-z]{1}[a-z0-9]{1})(  | $|$)/, 
                                      'del_regex' => / (d[~a-z}]{1}[~a-z0-9]{1})( |$)/  #,
                                      # 'del_regex' => / (d[~#{variable[0]}]{1}[~#{variable[1]}]{1})( |$)/  
                                    } 
                                  )
  end

   def each(&block)
    self.instance_variables.each do |instance_variable|
      block.call instance_variable
    end
  end
  
end
  
  
class Show_whatever 

  attr_reader :search_arr, :search_arr_object, :result_hash, :search_instructions_repository
  
  def initialize
    @search_arr_object = Search_arr.new
    @search_arr = self.search_arr_object.file_and_all_apf_names_and_contents_arr
    @search_instructions_repository = Search_instructions_repository.new
    @result_hash = self.find
  end 
  
  def delete_comments( line )
    line = line.sub(/\/\/.*$|  .*$/, '') || line
  end  
 
  def output_general_warnings
    self.search_arr_object.hints_hash.each do |key, files|
      files.each do |file|
      puts 'Warning! File is linked to but does not exist: ' + file
      end
    end
    puts ''
    puts self.search_arr_object.file_chooser.hints_hash.values[0]
  end
  
   def collect_general_warnings
    general_warnings = Show_tracer.new.get_specific_warnings
    self.search_arr_object.hints_hash.each do |key, files|
      files.each do |file|
      general_warnings << ( 'Warning! File is linked to but does not exist: ' + file )
      end
    end
    general_warnings << ''
    general_warnings << self.search_arr_object.file_chooser.hints_hash.values[0]
    general_warnings
  end
   
  # def output( hash )                                  #is this really useful?
  # end
  
  def find
    search_instructions_repository = self.search_instructions_repository
    found_hash = {}                                      
    self.iterate do |line, path_and_file| 
      search_instructions_repository.each do |repo|
        repo = repo.to_s.sub('@', '')
        search_instructions_repository.send( repo ).each do |name|
          name = name.to_s.sub('@', '')
          #if match successful
          if line && !line.scan( search_instructions_repository.send( repo ).send( name ) ).empty? 
            #make sure hash exists
            
            unless found_hash[repo]
              found_hash = found_hash.merge( { repo => { name => { path_and_file => Array.new } } } )
            end
            unless found_hash[repo][name]  
              temp = found_hash[repo].merge( { name => { path_and_file => Array.new } } )              
              found_hash[repo] = found_hash[repo].merge( temp )
            end
            unless found_hash[repo][name][path_and_file]    
            temp = found_hash[repo][name].merge( path_and_file => Array.new )
            found_hash[repo][name] = found_hash[repo][name].merge( temp )
            end                     
            #throw in 
            found_hash[repo][name][path_and_file] << line.scan( search_instructions_repository.send( repo ).send( name ) ).flatten  
          end
        end  
      end 
    end
    found_hash
  end
  
  def iterate( &block )                                      
    self.search_arr.each do |object|  
      path_and_file = object.path_and_file
      object.contents.each do |line|
        line = delete_comments( line )
        # do something
        block.call line, path_and_file
      end
    end
  end
  
  # def clean_search_instruction_names  #not in use but works
    # cleaned = []
    # self.search_instructions_repository.each do |name|
      # name = name.to_s.sub('@', '')
      # cleaned << name
    # end
    # cleaned
  # end  
  
end #class end

  
class Show_var < Show_whatever
  
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
  
  def find_old
    var_found_hash = self.search_for_variables
    total_distinct_variable_count = var_found_hash.values.flatten.uniq.count  
    total_occurences_variable_count = var_found_hash.values.flatten.count.to_s
    #save for output
    result_hash = {}
    result_hash = result_hash.merge( 'found' => var_found_hash )
    result_hash = result_hash.merge( 'total_disctinct_count' => total_distinct_variable_count )
    result_hash = result_hash.merge( 'total_occurences_count' => total_occurences_variable_count )
    #check if deleted
    result_hash = result_hash.merge( 'warning_not_deleted' => [] )
    var_found_hash.values.flatten.uniq.sort.each do |variable|
      deleted = self.is_deleted?( variable )
      unless deleted
        result_hash['warning_not_deleted'] << variable
      end
    end
    #free variables
    result_hash = result_hash.merge( 'free_count' => ( 936 - total_distinct_variable_count ) )
    #result
    result_hash
  end 
  
  def output
    puts '' #for readability
    puts '~~ Variables per file'
    puts ''
    self.result_hash['found'].each do |file, values|
      puts file.to_s 
      puts values.uniq.sort.join(', ')                     
      puts 'Total: ' + values.uniq.count.to_s
      puts ''
    end
    puts ''
    puts '~~ Summary'    
    puts ''
    puts self.result_hash['found'].values.flatten.uniq.join(', ')
    puts 'Total: ' + self.result_hash['found'].values.flatten.uniq.count.to_s
    puts 'Total occurences: ' + self.result_hash['total_occurences_count']
    #free variables
    puts 'Free variables left: ' + self.result_hash['free_count'].to_s
    puts ''  #for readability
    puts ''  #for readability
    puts '~~ Warnings'
    puts ''  #for readability
    #specific warnings
    self.output_specific_warnings
    # #general warnings  
    # self.output_general_warnings
  end
  
  def get_specific_warnings
    specific_warnings = if self.result_hash['warning_not_deleted'].count == 1
                          [ 'Warning! Variable that is never deleted: ' + "\n" + self.result_hash['warning_not_deleted'].join(', ') ]
                        elsif self.result_hash['warning_not_deleted'].count > 1
                          [ 'Warning! Variables that are never deleted: ' + self.result_hash['warning_not_deleted'].join(', ') ]
                        end
  end
  
  def output_specific_warnings
    unless self.get_specific_warnings.empty?
      self.get_specific_warnings.each { |warning| puts warning }
    else
      puts 'No warnings related to variables.'
    end
  end
    
end #class end


class Show_sr < Show_whatever

  attr_reader :search_arr, :search_arr_object
  
  # def initialize
    # super
  # end 
  
  def find_old
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
            warnings << 'Warning! Definition of subroutine ' + sr_start_found[0].to_s + ' starts before the end of conversion #+#.'
          end
          if file.end_with?('.apf')
            warnings << 'Warning! Subroutine defined in "' + file + '" (move to main file).'
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
          warnings << 'Warning! Subroutine ' + element + ' is not closed.'
        else
          subroutines << element
        end
        unless sr_jump_in_hash.values.flatten.include? element
          warnings << 'Info: Subroutine ' + element + ' is not used.'
        end
      end 
    end
    
    sr_jump_in_hash.each do |file, arr|
      arr.each do |element|
       unless sr_start_found_hash.values.flatten.include? element
          warnings << 'Warning! No subroutine ' + element + ' despite >' + element + ' in "' + file + '".'
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
    puts '~~ Subroutines'
    puts '' #for readability
    result_hash['sr_start_found_hash'].each do |file, arr|
      puts 'Subroutines implemented in file "' + file + '":'
      puts arr.sort.join(', ')
    end
    puts '' #for readability
    puts '' #for readability
    puts '~~ Warnings'
    puts '' #for readability
    self.output_specific_warnings
    # #output general warnings 
    # self.output_general_warnings
  end #method end
  
  def get_specific_warnings
    specific_warnings = result_hash['warnings'].uniq.sort.reject { |key, value| key if value =~ /^ *$/}
  end
  
  def output_specific_warnings
    unless self.get_specific_warnings.empty?
      puts self.get_specific_warnings
    else
      puts 'No warnings related to subroutines.'
    end
  end
      
end #class end


class Show_jl < Show_whatever
    
  # def initialize
    # super
  # end
  
  # constants
  ABC = [ 'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z'  ] 
  NUM = [  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9'  ]
  SYMBOL = [ '!', '"', '$', '%', '&', '/', '@', '=', '.', ',', ':', ';'  ]
  JL = ABC + ABC.map {|letter| letter.downcase } + NUM + SYMBOL
  
  def find_old
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
  warning_target_missing = warning_target_missing.uniq.sort.reject { |element| element if element =~ /^ *$/}  
  end #end method
  
  def check_target_not_unique( result_hash )
    sorted_per_type_targets_hash = sort_targets_per_type( result_hash )
    targets_type_label = sorted_per_type_targets_hash['label']
    #warnings
    warning_target_not_unique = []
    duplicates = targets_type_label.group_by{ |e| e }.keep_if{ |_, e| e.length > 1 }
    if duplicates.count > 0
      warning_target_not_unique = duplicates.sort.map { |arr| [ arr[0], arr[1] = arr[1].count ] }.reject { |element| element if element =~ /^ *$/} 
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
    
  def output
    result_hash = self.find
    all_jl_arr = []
    total_distinct_count = 0
    total_occurrences_count = 0
    puts ''
    puts '~~ Jump labels per file'
    puts ''
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
      puts ''
      puts '~~ Summary'
      puts ''
      puts all_jl_arr.uniq.sort.join(', ')
      puts 'Total: ' + all_jl_arr.uniq.count.to_s   
    end
    puts ''  #for readability
    #free jump labels
    if total_distinct_count > 0
      free_jl = JL - all_jl_arr.uniq
      puts ''
      puts 'FREE jump labels: ' 
      puts free_jl.join('  ')
      puts 'Total free: ' + free_jl.count.to_s 
    end
    puts ''  #for readability
    puts ''  #for readability
    #output specific warnings
    puts '~~ Warnings'
    puts ''
    self.output_specific_warnings 
    # #output general warnings
    # self.output_general_warnings
  end
  
  def get_specific_warnings
    check_results = self.run_checks    
    check_results_worded_out = []
    check_results_worded_out << 'Warning! No target exists for +' + check_results['missing'].join(', ') + '.'
    check_results['duplicates'].each do |duplicate, duplicate_count|
      check_results_worded_out << ( 'Warning! Target not unique: ' + duplicate + ' (' + duplicate_count.to_s + 'x).' )
    end
    check_results_worded_out
  end
  
  def output_specific_warnings
    unless self.get_specific_warnings
      self.get_specific_warnings.each do |warning|
        puts warning
      end
    else
      puts 'No warnings related to jump labels.'
    end
  end
  
end #class end


class Show_tracer < Show_whatever

  # attr_reader :search_arr
  
  # def initialize
    # super
  # end

  def get_specific_warnings
    tracer_warnings = []
    tracer_regex = /^#\?/
    self.search_arr.each do |object|  
        file = object.path_and_file
        object.contents.each_with_index do |line, index|
          unless line.scan( tracer_regex ).flatten.empty?
            tracer_warnings << ( 'Warning! Tracer left in "' + file + '" at line ' + ( index + 1 ).to_s )
          end
        end
    end 
    tracer_warnings    
  end      

  def output_specific_warnings
    tracer_warnings = self.get_specific_warnings
    unless tracer_warnings.count == 0
      puts ''
      puts tracer_warnings
    end
  end

end      


class Get_all_warnings
  
  attr_reader :warnings
  
  def initialize
  @warnings =   {
                  'var'     => Show_var.new.get_specific_warnings,
                  'sr'      => Show_sr.new.get_specific_warnings,
                  'jl'      => Show_jl.new.get_specific_warnings,
                  'info'    => Show_whatever.new.collect_general_warnings     #includes tracer warnings
                }
  end
 
  def output_all
    self.warnings.each do |topic, arr|
      arr.each do |warning|
        puts warning
      end
    end
  end
  
  def output( key )
    self.warnings[key].each do |warning|
      puts warning
    end
  end
  
  def output_except( *keys )
    warnings = self.warnings
    keys.each do |key|
      warnings = warnings.tap {|h| h.delete(key)}
    end
    warnings.each do |topic, arr|
      arr.each do |warning|
        puts warning
      end
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
    puts '-w'  + "\t" + 'to get all warnings'
    puts ''
    puts 'Example: ruby falcon.rb -jl -w'
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
      unless ['-var', '-sr', '-jl', '-w'].include? argument           #register new options HERE!!!
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
  
end  # class end






#main test


a = Show_jl.new
b = a.result_hash


b.each do |name, hash|
  puts name + '-->>>'
  hash.each do |file, result|
    print "\t"
    puts file + '-->'
    print "\t"
    p result 
  end
end


      
      
# # main
# system 'cls'
# separator = "\n#####>\n"
# separator_required = ( ( ARGV - ['-w'] ).count > 1 )

# if ARGV.count > 0
  # Validity_checker.new.output
# else
  # puts 'What do you want to do?'
  # Help.new
# end


# if ARGV.include?( '-var' )
  # print separator if separator_required
  # Show_var.new.output
# end

# if ARGV.include?( '-sr' )
  # print separator if separator_required
  # Show_sr.new.output
# end

# if ARGV.include?( '-jl' )
  # print separator if separator_required
  # Show_jl.new.output
# end

# if ARGV.include?( '-w' )
  # options = ARGV - [ '-w' ]
  # keys = options.map { |option| option = option.sub(/-/, '') }  
  # keys.push( 'info' )
  # Get_all_warnings.new.output_except( *keys )
# end

# Get_all_warnings.new.output( 'info' )

# puts ''




