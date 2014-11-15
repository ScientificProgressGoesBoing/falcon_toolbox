# require 'minitest/spec'
require 'minitest/autorun'
require_relative 'falcon'

class TestShow_whatever_inherited < MiniTest::Unit::TestCase
  PARAMETERS.keys.each do |parameter|
    name = parameter.to_s.sub('-', 'Show_')
    object = instance_eval( "#{name}.new" )
    
    # define_method( 'test_refine_hash_is_a_hash_' + name ) do
      # assert_equal Hash, object.refine.class
    # end    
    # define_method( 'test_refine_hash_output_is_a_hash_' + name ) do
      # assert_equal Hash, object.refine['output'].class
    # end    
    # define_method( 'test_run_checks_returns_array_' + name ) do
      # assert_equal Array, object.run_checks( object.refine ).class
    # end    
    # define_method( 'test_get_specific_warnings_returns_array_' + name ) do
      # assert_equal Array, object.get_specific_warnings.class
    # end 
    
    define_method( 'test_refine_returns_hash_' + name ) do
      assert_instance_of Hash, object.refine
    end     

    define_method( 'test_refine_hash_output_is_a_hash_' + name ) do
      assert_instance_of Hash, object.refine['output']
    end

    define_method( 'test_run_checks_returns_array_' + name ) do
      assert_instance_of Array, object.run_checks( object.refine )
    end     
    
    define_method( 'test_get_specific_warnings_returns_array_' + name ) do
      assert_instance_of Array, object.get_specific_warnings
    end      
  end
end  
  
  
class TestShow_var < MiniTest::Unit::TestCase   
  def setup
    @show_var = Show_var.new
  end
 
  def test_variable_is_deleted_generally
    assert_equal true, @show_var.is_deleted?( 'er', { 'test' => ['d~~'] }  )
  end
  
  def test_variable_is_deleted_individually
    assert_equal true, @show_var.is_deleted?( 'er', { 'test' => ['der'] }  )
  end
  
  def test_variable_not_deleted
    assert_equal false, @show_var.is_deleted?( 'er', { 'test' => [] }  )
  end  
  
  def test_variable_not_deleted_other
    assert_equal false, @show_var.is_deleted?( 'er', { 'test' => ['dst'] }  )
  end  
end


class TestFile_chooser < MiniTest::Unit::TestCase 
  def setup
    @file_chooser = File_chooser.new
  end
  
  def test_file_list_generator_returns_array
    assert_instance_of Array, @file_chooser.file_list_generator
  end  
  
  def test_file_choice_suggester_returns_array
    assert_instance_of Array, @file_chooser.file_choice_suggester
  end  
  
  def test_file_choice_suggester_produces_output
    assert_output( /apf|fcv|tmpl|ipa/ ) {  @file_chooser.file_choice_suggester }
  end    
  
  # def test_file_choice_reader_produces_confirmation_output
    # assert_output( /You chose file/ ) { @file_chooser.file_choice_reader }
  # end 
    
  def test_file_choice_reader_produces_confirmation_output
    printed = nil
    @file_chooser.instance_eval do
    # Open up the instance and stub out the puts method to save to a local variable
      # self.class.send( define_method, :puts, Proc.new {|arg| printed = arg} )
      self.create_method( :puts ) {|arg| printed = arg} 
    end
    # Run code
    refute printed.nil?
  end 
  
  # def test_file_choice_reader_handles_invalid_input
    # assert_instance_of Array, @file_chooser.file_choice_reader
  # end  
  
  
  # assert_respond_to(obj, meth, msg = nil)
  
  #
  
  #cookie_writer(text)
end










