#This ruby script shows a list of all falcon FEL jump labels already used
#Adjust path 'param' as needed
#To be used with .fcv, .ipa, and .tmpl files

#Requires ruby installation 1.9.3 or above
#Execute with
#ruby show_jl.rb


#TODO: findet die nach #+I noch nicht !!!

#TODO: loop für unterverlinkte apf-files
#todo: apf files verlinkt aus ... anzeigen

#TODO: freie Sprungziele!! (damit nicht immer falcon run!)

#TODO: Gesamtanzeige aller Jump Labels, Gesamtcount

#TODO: unmatched labels
#TODO: Sprungziel unklar

#TODO: Sprungziel liegt nicht innerhalb derselben Unterroutine

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



class Show_jl
  
  def initialize
    @path_and_file = File_chooser.new.file_choice_reader
    @path = @path_and_file.sub(/\/.+/, '')
    @file = @path_and_file.sub(/.+\//, '')
    find_jl
  end 
  
  def file_arr
    [ [@file], [File.readlines( @path_and_file.to_s )]  ]
  end
  
  def find_apf(arr = file_arr[1])
    match_apf = []
    arr.each do |lines| 
      lines.each do |l|
        match_apf << l.match(/^t([^ \#]+) /)
      end
    end
    apf_file_names = match_apf.reject { |l| l == nil  }
  end

  # returniert ein Array bestehend aus [0] apf_file_names_clean und [1] apf_contents
  def apf_arr
    apf_file_names = find_apf
    apf = []
    if apf_file_names.count > 0 
      apf_contents = []
      apf_file_names_clean = []
      apf_file_names.each do |tfile|
        apf_file_names_clean << tfile[1] + '.apf'
        apf_path_and_file = @path + '/' + tfile[1] + '.apf'
        apf_contents <<  File.readlines(apf_path_and_file) 
      end 
      apf << apf_file_names_clean
      apf << apf_contents
    end
    apf
  end
  
  def work_arr_generator
    unless apf_arr.empty?
      [  file_arr[0] + apf_arr[0], file_arr[1] + apf_arr[1]  ]
    else
      file_arr
    end   
  end
  
  def find_jl
    file_names_and_contents_arr = work_arr_generator
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
      if file_names.count > 1 && j > 0
        puts 'Jump Labels in all files:'
        md_arr_all_files.uniq.sort.each do |jl_all_files|
          jl = jl_all_files[0]
          puts jl.sub!(/^[^+]\+/, '')
        end
        puts 'Total: ' + md_arr_all_files.uniq.count.to_s
      end
    end
    j > 0 ? 1 : 0
  end
    
end #class end

#main
Show_jl.new





