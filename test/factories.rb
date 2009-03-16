# When you make a factory, make a corresponding create_new_xxxxx  tasks which
# checks if it exists (if nessessary) and return existing one if so, or make
# a new one, assert it's a kind_of class we want, and return that

#
# Do not make the following factories
# (because they are cached, so make sure you run through them via click/fill_in etc)
#
# Topic   (makes homepage and topic show page caches)
#


#
# Basket Factory
#
Factory.define :basket do |b|
  b.name 'Test Basket'
  b.status 'approved'
  b.creator_id 1
end
def create_new_basket(options)
  @basket = Basket.find_by_name(options[:name])
  return @basket unless @basket.nil?
  @basket = Factory(:basket, options)
  assert_kind_of Basket, @basket
  @basket
end


#
# User Factory
#
Factory.define :user do |u|
  u.login 'joe'
  u.email { |e| "#{e.login}@ketetest.co.nz".downcase }
  u.salt '7e3041ebc2fc05a40c60028e2c4901a81035d3cd'
  u.crypted_password '00742970dc9e6319f8019fd54864d3ea740f04b1' # test
  u.created_at Time.now.to_s(:db)
  u.updated_at Time.now.to_s(:db)
  u.activation_code 'admincode'
  u.activated_at Time.now.to_s(:db)
  u.agree_to_terms true
  u.security_code "a"
  u.locale "en"
end
# this shouldn't be called directly, use the method missing functionality to add users on the fly
# add_bob_as_tech_admin(:baskets => @@site_basket)
def create_new_user(options)
  @user = User.find_by_login(options[:login])
  return @user unless @user.nil?
  @user = Factory(:user, options)
  assert_kind_of User, @user
  @user
end

#
# Extended Field
#
Factory.define :extended_field do |ef|
  ef.label 'A bit of data'
  ef.description 'a description of the field for admins'
end
def create_extended_field(options)
  @extended_field = ExtendedField.find_by_label(options[:label])
  return @extended_field unless @extended_field.nil?
  @extended_field = Factory(:extended_field, options)
  assert_kind_of ExtendedField, @extended_field
  @extended_field
end
