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
        del_found = line.scan( del_regex ).flatten[0]
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
    
  end #end method

    
end #class end

# main
Show_var.new.find_var


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#TODO: count "=" as deleting a variable