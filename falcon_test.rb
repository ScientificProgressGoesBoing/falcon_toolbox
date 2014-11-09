require 'minitest/autorun'
require_relative 'falcon'

class Show_whatever_inherited_test < MiniTest::Unit::TestCase
  PARAMETERS.keys.each do |parameter|
    name = parameter.to_s.sub('-', 'Show_')
    object = instance_eval( "#{name}.new" )
    
    define_method( 'test_refine_hash_is_a_hash_' + name ) do
      assert_equal Hash, object.refine.class
    end
    
    define_method( 'test_refine_hash_output_is_a_hash_' + name ) do
      assert_equal Hash, object.refine['output'].class
    end
    
    define_method( 'test_run_checks_is_a_array_' + name ) do
    assert_equal Array, object.run_checks( object.refine ).class
    end    
  end
  
end  
  
class Show_var_test < MiniTest::Unit::TestCase    
  def test_variable_is_deleted_generally
    assert_equal true, Show_var.new.is_deleted?( 'er', { 'test' => ['d~~'] }  )
  end
  
  def test_variable_is_deleted_individually
    assert_equal true, Show_var.new.is_deleted?( 'er', { 'test' => ['der'] }  )
  end
  
  def test_variable_not_deleted
    assert_equal false, Show_var.new.is_deleted?( 'er', { 'test' => [] }  )
  end  
  
  def test_variable_not_deleted_other
    assert_equal false, Show_var.new.is_deleted?( 'er', { 'test' => ['dst'] }  )
  end  
end
