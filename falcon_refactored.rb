#This ruby script performs several falcon FEL syntax checks
#Adjust path 'param' as needed
#To be used with .fcv, .ipa and .tmpl files

#Requires ruby installation 1.9.3 or above
#Execute with
#ruby falcon.rb

#Available options
#-var   list variables
#-sr    list subroutines
#-jl    list jump labels
#-tr    list trailing tracers


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#TODO: count "=" as deleting a variable
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  ##~~Documentation~~##
  
  ##Classes##
  #File_chooser
  #File_name_and_contents
  #Search_arr
  #Search_instruction
  #Search_instructions_repository
  #Show_whatever #and inheriting classes: Show_var, Show_sr, Show_jl, Show_tr
  #Get_all_warnings
  #Help

  #~~~
  
  ## Show_whatever 

  ## instance variables + attr_reader 
  #@search_arr_object
  #@search_arr
  #@search_instructions_repository
  #@result_hash

  ## methods
  # search_arr_generator
  # search_instructions_repository_generator
  # collect_general_warnings
  # delete_comments( line )
  # find                                  
  # get_applicable_result
  # iterate( &block )   
  # iterate_applicable_result( &block )
  # output_per_file( hash, header )     
  # output_summary( hash, header )      
  # output_general_warnings
  # output
  # refine
  # get_specific_warnings
  # def clean_search_instruction_names  #not in use but works

  ## methods *required* in inheriting classes
  # run_checks( refine_hash ) 
  # output_specific_warnings
  ##optional
  # output_specific( number )

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


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

  #readers are set dynamically in initialize

  # def initialize
    # Show_whatever.subclasses.each do |subclass|
      # instance_variable_set("@#{subclass.to_s.downcase}", subclass.new.search_instruction)
      # self.class.send(:attr_reader, subclass.to_s.downcase)
    # end
  # end
 
  def initialize
    @sr = search_instruction_generator( 
                                        { 
                                          'jump_in_sr_regex' => /[^ ]{1} >([a-z]{1})( | $|$)/ ,   
                                          'sr_start_regex' => /^#\(([a-z]{1})( | $|$)/ ,
                                          'end_sr_regex' => /^#\)([a-z]{1})( | $|$)/ ,
                                          'conversion_end_regex' => /^(#\+#)( | $|$)/ 
                                        } 
                                      )
     
    @jl = search_instruction_generator( 
                                        { 
                                          'jl_regex' => /( |^#)\+([#]?[^+ #-]+)([^#]+|$)/ ,
                                          'target_regex' => /^(#-[^+ #]+)($| )|^(#[^+ #]+)($| )/ 
                                        } 
                                      )
                                           
    @var = search_instruction_generator(
                                          { 
                                            'var_regex' => / ([aA=]{1})([a-z]{1}[a-z0-9]{1})(  | $|$)/, 
                                            'del_regex' => / (d[~a-z}]{1}[~a-z0-9]{1})( |$)/                                      
                                          } 
                                        )
    
    @tr = search_instruction_generator(
                                        {
                                          'tr_regex' => /^(#\?)/
                                        }    
                                      )
    #set readers dynamically
    instance_variables.each do |iv|
      name = iv.to_s.sub('@', '')
      self.class.send(:attr_reader, name)
    end 
    
  end

  def each(&block)
    self.instance_variables.each do |instance_variable|
      block.call instance_variable
    end
  end
  
  def search_instruction_generator( hash )
    Search_instruction.new( hash )
  end
  
end
  
  
class Show_whatever 

  attr_reader :search_arr, :search_arr_object, :result_hash, :search_instructions_repository
  
  def initialize
    @search_arr_object = search_arr_generator
    @search_arr = self.search_arr_object.file_and_all_apf_names_and_contents_arr
    @search_instructions_repository = search_instructions_repository_generator
    @result_hash = self.find
  end 
  
  def search_instructions_repository_generator
    Search_instructions_repository.new
  end
  
  def search_arr_generator
    Search_arr.new
  end
  
  def delete_comments( line )
    line = line.sub(/\/\/.*$|  .*$/, '') || line
  end  
  
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
  
  def get_applicable_result
    result = self.result_hash[self.class.to_s.downcase.sub(/^.*_/, '')]
  end
  
  def iterate_applicable_result( &block )
    self.get_applicable_result.each do |regex_name, hash|
      block.call regex_name, hash
    end
  end
  
  def output_per_file( hash, header = '### Result per file: ', message = '' )     
    puts ''
    puts header
    puts ''
    hash.each do |filename, elements|
      puts message + filename
      puts elements.join(', ')
      puts 'Total: ' + elements.count.to_s
      puts ''
    end
  end
  
  def output_summary( hash, header = '>>> Summary (all files): ' )      
    puts header
    all_elements = hash.values.flatten.uniq.sort
    puts all_elements.join(', ')
    puts 'Total: ' + all_elements.count.to_s
    self.output_specific( all_elements ) 
    puts ''
  end
  
  def output_specific( number )
    #Needs to be implemented in each class.
  end
  
  def output_general_warnings
    general_warnings = collect_general_warnings
    general_warnings.each { |warning| puts warning  }
  end
  
  def collect_general_warnings
    general_warnings = []
    general_warnings = Show_tr.new.get_specific_warnings unless self.class.to_s == 'Show_tr'
    self.search_arr_object.hints_hash.each do |key, files|
      files.each do |file|
        general_warnings << ( 'Warning! File is linked to but does not exist: ' + file )
      end
    end
    general_warnings << ''
    general_warnings << self.search_arr_object.file_chooser.hints_hash.values[0]
    general_warnings
  end
  
  def output
    output_per_file( output_hash = self.refine['output'] )
    output_summary( output_hash = self.refine['output'] )
    output_specific_warnings
    output_general_warnings
  end
 
  def refine
    refine_hash = {}
    self.iterate_applicable_result do |regex_name, hash|
      name = regex_name.sub(/^([^_]+)_.+/, '\1')
      if name == self.class.to_s.downcase.sub(/^.*_/, '')
        params = [ name, hash ]    
        refine_hash = refine_hash.merge ( { 'output' => self.send( 'refine_case'.to_sym, *params ) } ) 
      else
        refine_hash = refine_hash.merge ( { name => self.refine_case( name, hash ) } ) 
      end
    end
    refine_hash
  end
  
  def get_specific_warnings
    run_checks( self.refine )
  end  
  
  def output_specific_warnings
    # Needs to be implemented in each class. #Dummy needed here.
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
  
  def refine_case( name, hash )
    case name
      when 'var'          
        var_hash = {}          
        var_assign_hash = {}
        hash.each do |file_name, value_arr|
          var_arr = []
          var_assign_arr = []
          value_arr.each do |arr|
            var_arr << arr[1]
            var_assign_arr << ( arr[0] + arr[1] ) if arr[0] == '='
          end
          var_hash = var_hash.merge( { file_name => var_arr.uniq.sort } )
          var_assign_hash = var_assign_hash.merge( { file_name => var_assign_arr.uniq.sort } )            
        end
        return_hash = var_hash
        #TODO: how get the assign_hash out without disturbing the rest?? 
      when 'del'
        del_arr = []
        del_hash = {}
        hash.each do |file_name, value_arr|
          value_arr.each do |arr|
            del_arr << arr[0]
          end
          del_hash = del_hash.merge( { file_name => del_arr.uniq.sort } )
        end
        return_hash = del_hash   
    end
    return_hash
  end 
    
  def run_checks( refine_hash )
    var = refine_hash['output']
    del = refine_hash['del']    
    #all variables deleted?
    not_deleted = []
    var.each do |variable|
      not_deleted << variable unless is_deleted?( variable, del ) #|| !assigned_with_equal_sign?( variable, assign_hash )
    end
    if not_deleted.count == 1
      warning = 'Warning! Variable that is never deleted: '
    elsif not_deleted.count > 1
      warning = 'Warning! Variables that are never deleted: '
    end
    {
      warning => not_deleted
    }
  end
  
  def is_deleted? ( variable, del_hash )
    del_regex = /(d[~#{variable[0]}]{1}[~#{variable[1]}]{1})/
    del_hash.each do |file_name, arr|
      arr.each do |del_variable|
        return true if del_variable =~ del_regex 
      end
    end
    return false
  end
  
  def assigned_with_equal_sign?( variable, assign_hash )
    assign_hash.each do |file_name, arr|
      return true if arr.include? variable    
    end
    return false
  end
  
  def output_specific( all_elements )
    number = all_elements.count
    puts 'Free variables: ' + ( 936 - number ).to_s
  end
  
  #TODO: distinct count vs. summarized count
  
  def output_specific_warnings
    specific_warnings = self.get_specific_warnings
    unless specific_warnings.empty?
      specific_warnings.each do |warning, hash| 
        print warning 
        hash.each do |file_name, arr|
          puts arr.join(', ') # + ' (' + file_name + ') '
        end
      end
    else
      puts 'No warnings related to variables.'
    end
  end
    
end #class end


class Show_sr < Show_whatever

   def refine_case( name, hash )
    case name
    when 'jump'
          jump_in_hash = {}
          hash.each do |file_name, value_arr|
            jump_in_arr = []
            value_arr.each do |arr|
              jump_in_arr << arr[0]
            end
            jump_in_hash = jump_in_hash.merge( { file_name => jump_in_arr.uniq.sort } )
          end
          return_hash = jump_in_hash
    when 'sr'          
          sr_start_hash = {}
          hash.each do |file_name, value_arr|
            sr_start_arr = []
            value_arr.each do |arr|
              sr_start_arr << arr[0]
            end
            sr_start_hash = sr_start_hash.merge( { file_name => sr_start_arr.uniq.sort } )
          end
          return_hash = sr_start_hash         
    when 'end'
          sr_end_hash = {}          
          hash.each do |file_name, value_arr|
            sr_end_arr = []
            value_arr.each do |arr|
              sr_end_arr << arr[0]
            end
            sr_end_hash = sr_end_hash.merge( { file_name => sr_end_arr.uniq.sort } )
          end
          return_hash = sr_end_hash   
    when 'conversion'
          conversion_end_hash = {}        
          line_number = nil          
          hash.each do |file_name, value_arr|
            unless file_name.end_with? '.apf'
              conversion_end_arr = []
              value_arr.each do |arr|
                conversion_end_arr << arr[0]
              end   
              unless conversion_end_arr.empty?
                conversion_end_hash = conversion_end_hash.merge(  file_name => conversion_end_arr  )
              end
            end
          end
          if conversion_end_hash.empty?
            conversion_end_hash = { 'Warning! Conversion end missing.' => '' }
          else
            file_name = conversion_end_hash.keys[0]
            File.readlines( file_name ).each_with_index do |line, index|
              line_number = ( index + 1 ) if line.match(/#\+#/)
            end
            conversion_end_hash = conversion_end_hash.merge( { file_name => line_number } )
          end     
          return_hash = conversion_end_hash
    end
    return_hash
  end  
  
  def run_checks( refine_hash )
    hash_to_check = refine_hash
    specific_warnings_arr = []
    #no conversion end sign
    if hash_to_check['conversion'].keys[0] =~ /Warning/
      specific_warnings_arr << hash_to_check['conversion'].keys[0]
    end
    #starts not in right file 
    if hash_to_check['output'].count > 1
      collect_warnings = {}
      hash_to_check['output'].each do |file_name, arr|       
        unless file_name.end_with?( '.tmpl', '.fcv', '.ipa' )
          collect_warnings = collect_warnings.merge( { file_name => arr } )
          hash_to_check['output'] = hash_to_check['output'].tap { |h| h.delete( file_name ) }
        end
      end
      collect_warnings.each do |file_name, arr|
      specific_warnings_arr << ( 'Warning! Subroutine not defined in main file: ' + arr.join(', ') + ' in ' + file_name + '.' )
      end
    end
    #jumped in but does not exist 
    if hash_to_check['jump'].any?
      hash_to_check['jump'].each do |file_name, arr|
        arr.each do |element|
          unless hash_to_check['output'].values.include? element 
            specific_warnings_arr << 'Warning! No subroutine ' + element + ' despite >' + element + ' in "' + file_name + '".'   
          end
        end
      end
    end
    if hash_to_check['output'].any?
      hash_to_check['output'].values.flatten.uniq.each do |element|
        #not closed  
        unless hash_to_check['end'].values.flatten.uniq.include? element
          specific_warnings_arr << 'Warning! Subroutine ' + element + ' is not closed.'
        end
        #Info: not used
        unless hash_to_check['jump'].values.flatten.uniq.include? element
          specific_warnings_arr << 'Info: Subroutine ' + element + ' is not used.'
        end
      end    
    end
    #start before conversion_end
    if hash_to_check['output'].count == 1
      hash_to_check['output'].each do |file_name, arr|
        arr.each do |element|
          File.readlines( file_name ).each_with_index do |line, index|
            if line.match( /\#\(#{element}/ )
              line_number = index + 1
              if line_number <= hash_to_check['conversion'].values[0]
                specific_warnings_arr << 'Warning! Subroutine ' + element + ' starts before end of conversion.'
              end
            end
          end
        end
      end
    end
    specific_warnings_arr.uniq.sort
  end
  
  def output_specific( number )
    #TODO: Needs to be implemented in each class.
    []
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
  
  # constants
  ABC = [ 'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z'  ] 
  NUM = [  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9'  ]
  SYMBOL = [ '!', '"', '$', '%', '&', '/', '@', '=', '.', ',', ':', ';'  ]
  JL = ABC + ABC.map {|letter| letter.downcase } + NUM + SYMBOL
  
  def refine_case( name, hash )
    case name
      when 'jl'
        jl_hash = {}
        hash.each do |file_name, value_arr|
          jl_arr = []
          value_arr.each do |arr|
            jl_arr << arr[1].chomp unless arr[1].chomp == '#'
          end
          jl_hash = jl_hash.merge( { file_name => jl_arr.uniq.sort } )
        end
        return_hash = jl_hash
      when 'target'
        label_arr = []
        field_arr = []
        hash.each do |file_name, value_arr|
          value_arr.each do |arr|
            label_arr << arr[0].chomp unless arr[0] == nil
            field_arr << arr[2].chomp unless arr[2] == nil
          end
        end
        target_hash = { 
                        'label' => ( label_arr.sort ),  #not uniq because later check for not uniqe targets
                        'field' => ( field_arr.sort )
                      }  
        return_hash = target_hash
    end
    return_hash
  end
  
  def run_checks( refine_hash )
    hash_to_check = refine_hash    
    specific_warnings_arr = []
    #run checks
    specific_warnings_arr << check_target_missing( hash_to_check['target'], hash_to_check['output'] )
    specific_warnings_arr << check_target_not_unique( hash_to_check['target'] )
    #result
    specific_warnings_arr
  end
  
  def output_specific( all_elements ) 
      free_jl = JL - all_elements
      puts ''
      puts 'FREE jump labels: ' 
      puts free_jl.join('  ')
      puts 'Total free: ' + free_jl.count.to_s 
  end
  
  def check_target_missing( hash, output_hash )
    sorted_per_type_targets_hash = hash
    #check
    target_missing = []
    output_hash.each do |file, arr|
      arr.each do |jl|
        #check if matching target exists
        conjectured_target_label = '#-' + jl
        unless  sorted_per_type_targets_hash['label'].uniq.find { |e| /#{conjectured_target_label}/ =~ e } ||  #type #-A
                sorted_per_type_targets_hash['field'].uniq.find { |e| /#{jl}/ =~ e }                         #type field            
          target_missing << jl
        end
      end
    end
    target_missing = target_missing.uniq.sort.reject { |element| element if element =~ /^ *$/}  
    #word out warnings
    if target_missing.any?
      missing_warnings = []
      target_missing.each do |target|
        missing_warnings << ( 'Warning! No target exists for +' + target + '.' )
      end
    end
    missing_warnings.uniq.sort
  end #end method
  
  def check_target_not_unique( sorted_per_type_targets_hash )
    targets_type_label = sorted_per_type_targets_hash['label']
    #check
    warning_target_not_unique = []
    duplicates = targets_type_label.group_by{ |e| e }.keep_if{ |_, e| e.length > 1 }
    if duplicates.count > 0
      warning_target_not_unique = duplicates.sort.map { |arr| [ arr[0], arr[1] = arr[1].count ] }.reject { |element| element if element =~ /^ *$/ } 
    end
    #word out warnings
    duplicate_warnings = []
    if warning_target_not_unique.any?    
      warning_target_not_unique.uniq.each do |duplicate, duplicate_count|
        duplicate_warnings << ( 'Warning! Target not unique: ' + duplicate + ' (' + duplicate_count.to_s + 'x).' )
      end
    end
    duplicate_warnings.uniq.sort
  end #end method
    
  def output_specific_warnings
    if self.get_specific_warnings.any?
      self.get_specific_warnings.each do |warning|
        puts warning
      end
    else
      puts 'No warnings related to jump labels.'
    end
  end
  
end #class end


class Show_tr < Show_whatever

  def refine_case( name, hash )
    case name
      when 'tr'
        tracer_hash = {}
        hash.each do |file_name, tracer_arr|
          tracer_hash = tracer_hash.merge(  file_name => tracer_arr.flatten  )
        end
        return_hash = tracer_hash
    end
    return_hash
  end
  
  def run_checks( refine_hash )
    self.check_which_line
  end 
  
  def check_which_line
    tracer_warnings = []
    tracer_regex = self.search_instructions_repository.tr.tr_regex
    self.refine['output'].keys.each do |file_name| 
        self.search_arr.each do |object|  
          if object.path_and_file == file_name
            object.contents.each_with_index do |line, index|
              unless line.scan( tracer_regex ).flatten.empty?
                tracer_warnings << ( 'Warning! Tracer left in "' + file_name + '" at line ' + ( index + 1 ).to_s )
              end
            end
          end
        end
    end 
    tracer_warnings    
  end 
  
  #redundant as tracer warnings are included in general warnings
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
                  # 'tr'      => Show_tr.new.get_specific_warnings,
                  'info'    => Show_whatever.new.collect_general_warnings  #includes tracer warnings
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

  attr_reader :invalid_arguments

  def initialize
    @invalid_arguments = self.check_validity
  end
  
  def list_options
    puts 'Available options: '
    puts '-var' + "\t" + 'list Variables'
    puts '-sr'  + "\t" + 'list Subroutines'
    puts '-jl'  + "\t" + 'list Jump Lables'
    puts '-tr'  + "\t" + 'list trailing tracers'
    puts '-w'   + "\t" + 'get all warnings'
    puts ''
    puts 'Example: ruby falcon.rb -jl -w'
    puts '(combination of options is possible)'    
  end

  def check_validity
    invalid_arguments = []
    valid_arguments = []
    ARGV.each do |argument|
      unless ['-var', '-sr', '-jl', '-tr', '-w'].include? argument           #register new options HERE!!!
        invalid_arguments << argument
      else
        valid_arguments << argument
      end
    end
    invalid_arguments
  end
  
  def output_validity_check
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

      
      
# main
system 'cls'
separator = "\n#####>\n"
separator_required = ( ( ARGV - ['-w'] ).count > 1 )
help = Help.new

if ARGV.count > 0
  help.output_validity_check
else
  puts 'What do you want to do?'
  help.list_options
end

parameters = %w(-var -sr -jl -tr)

ARGV.each do |argument|
  if parameters.include? argument
    print separator if separator_required
    name = argument.to_s.sub('-', 'Show_')
    object = instance_eval( "#{name}.new" )
    object.send( 'output' )  
  end
end

if ARGV.include?( '-w' )
  options = ARGV - [ '-w' ]
  keys = options.map { |option| option = option.sub(/-/, '') }  
  keys.push( 'info' )
  Get_all_warnings.new.output_except( *keys )
end

puts ''




