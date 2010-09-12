# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
Redis::Objects.redis = $redis



describe Redis::Objects::Schema do
  it "should validate length" do
    schema = Redis::Objects::Schema.new do
      title Redis::Objects::V.length(3,5)
    end
    schema.validate({'title'=>'hello'}).should.be.true
    schema.validate({'title'=>'hell☃'}).should.be.true
    lambda { schema.validate({'title'=>'he'}) }.should.raise
    lambda { schema.validate({'title'=>'helloo'}) }.should.raise
  end

  it "should support multiple validations" do
    schema = Redis::Objects::Schema.new do
      title Redis::Objects::V.required, Redis::Objects::V.length(3,5)
    end
    schema.validate({'title'=>'hello'}).should.be.true
    lambda { schema.validate({}) }.should.raise
    lambda { schema.validate({'title'=>'he'}) }.should.raise
  end

  it "should support validating by type" do
    schema = Redis::Objects::Schema.new do
      words Integer
    end
    schema.validate({'words' => 3}).should.be.true
    lambda { schema.validate({'words' => 'words'}) }.should.raise
  end

  it "should support required by !?" do
    schema = Redis::Objects::Schema.new do
      title!
    end
    schema.validate({'title'=>'hello'}).should.be.true
    lambda { schema.validate({}) }.should.raise
  end


  # it "should reject validations that are unknown" do
  #   lambda { schema = Redis::Objects::Schema.new do
  #     title blahvalidation
  #   end }.should.raise
  # end
end

module CustomValidations
  def self.custom_validation
    lambda { |val| raise unless !val || val =~ /hello/ }
  end
end

class Post < Redis::Objects::Model
  schema do
    title!
    words Integer
    author V.length(3,20)
    tag CustomValidations.custom_validation
    # created_at :marshal=>true
    body
  end

  def initialize(id=1) @id = id end
  def id; @id; end
end

describe Redis::Objects::Model do
  before do
    $redis.del('post:1:attrs')
  end

  it "should include Redis::Objects as well" do
    Post.redis.class.should == Redis
  end

  it "should set a hash on attrs" do
    Post.new.attrs.class.should == Redis::Hash
  end

  it "should add a save method" do
    Post.new(1).save('title'=>'My Post')
    Post.redis.hget('post:1:attrs', 'title').should == "My Post"
  end

  it "should validate keys" do
    lambda { Post.new.save('badkey'=>'hey') }.should.raise
  end

  it "should call validation methods" do
    lambda { Post.new(1).save('body'=>'My Post') }.should.raise
  end

  it "should call custom validation" do
    lambda { Post.new(1).save('title'=>'Post', 'tag'=>'ho') }.should.raise
    Post.new(1).save('title'=>'Post', 'tag'=>'hello')
  end

  # it "should support marshalling of types" do
  #   Post.new(1).save('title'=>'My Post', 'created_at'=>Time.now)
  #   Post.new(1).attrs['created_at'].class.should == Time
  # end
end
