#This ruby script shows a deduplicated list of all falcon FEL variables currently in use
#Adjust path 'param' as needed
#To be used with .fcv, .ipa and .tmpl files

#Requires ruby installation 1.9.3 or above
#Execute with
#ruby show_var.rb

path = 'param'


unless File.exists? 'Cookie.txt'

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

  if file_list.count > 0
    file_list.each_with_index do |file, index|
      puts index.to_s + ' ' + file
    end
    puts 'Choose file by typing index number!'
    chosen_file = gets.chomp
    abort ('No valid index number.') if /[^0-9]/.match(chosen_file)
    puts chosen_file = chosen_file.to_i
    if chosen_file >= file_list.count
      abort ('No valid index number.')
    else
        target_file = open('Cookie.txt', 'w')
        target_file.write file_list[chosen_file].to_s
        target_file.close
    end
    puts 'You chose file: ' + file_list[chosen_file].to_s
        path_and_file = file_list[chosen_file].to_s
  else 
    puts 'Neither .fcv nor .tmpl nor .ipa nor .apf files in directory.'  
  end
  
else

  pre_chosen_file = File.read('Cookie.txt')
  path_and_file = pre_chosen_file.chomp.to_s
  
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
  



if File.exists?(path_and_file)
  variable_regex = / [aA=]{1}[a-z]{1}[a-z0-9]{1}/
  puts '* Change file by deleting Cookie.txt (type: del Cookie.txt). *'
  puts 'Variables in file: ' + path_and_file.to_s
	#read input file
	contents = File.read(path_and_file)
	#delete comments
	contents = contents.gsub(/\/\/.*$|  .*$/, '')
	#find variables
	md = contents.scan( variable_regex ).uniq
	if md.empty?
	  puts "No variables found."
	else 
		variables = Array.new
		md.each do |m|
      variables.push( m.gsub(/^ .{1}/,'') )
		end
    i = 0
		variables.uniq.sort.each_with_index do |var, index|
      puts var
      i = index
		end
    puts 'Total: ' + ( i + 1 ).to_s
    #puts 'Free variable names: ' + ( 936 - (i + 1) ).to_s
	end	

else
  puts 'No such file in directory: ' + path_and_file
  exit
end