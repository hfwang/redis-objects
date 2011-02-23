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
    lambda { schema.validate({'title'=>'he'}) }.should.raise Redis::Objects::V::ValidationError
    lambda { schema.validate({'title'=>'helloo'}) }.should.raise Redis::Objects::V::ValidationError
  end

  it "should support multiple validations" do
    schema = Redis::Objects::Schema.new do
      title Redis::Objects::V.required, Redis::Objects::V.length(3,5)
    end
    schema.validate({'title'=>'hello'}).should.be.true
    lambda { schema.validate({}) }.should.raise Redis::Objects::V::AttributeRequired
    lambda { schema.validate({'title'=>'he'}) }.should.raise Redis::Objects::V::ValidationError
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
    lambda { schema.validate({}) }.should.raise Redis::Objects::V::AttributeRequired
  end


  # it "should reject validations that are unknown" do
  #   lambda { schema = Redis::Objects::Schema.new do
  #     title blahvalidation
  #   end }.should.raise
  # end
end

module CustomValidations
  def self.custom_validation
    lambda { |key,val| raise unless !val || val =~ /hello/ }
  end
end

module PasswordMarshal
  def self.dump(val)
    val + "_encrypted"
  end

  def self.restore(val)
    val.split("_encrypted").first
  end
end

class Post < Redis::Objects::Model
  schema do
    title!
    words Integer
    author V.length(3,20)
    tag CustomValidations.custom_validation
    created_at :marshal=>true
    password V.length(3, 200), :marshal=>PasswordMarshal
    body
  end

  def initialize(id=1) @id = id; end
  def id; @id; end
end

class Link < Redis::Objects::Model
  key :incr
  schema do
    url!
  end
end

class Account < Redis::Objects::Model
  key :length=>5
  schema do
    name
  end
end

describe Redis::Objects::Model do
  before do
    $redis.flushdb
  end

  it "should include Redis::Objects as well" do
    Post.redis.class.should == Redis
  end

  it "should set a hash on attrs" do
    Post.new.attrs.class.should == Redis::HashKey
  end

  it "should add a save method" do
    Post.new(1).save('title'=>'My Post')
    Post.redis.hget('post:1:attrs', 'title').should == "My Post"
  end

  it "should validate keys" do
    lambda { Post.new(1).save('badkey'=>'hey') }.should.raise Redis::Objects::V::AttributeNotSpecified
  end

  it "should call validation methods" do
    lambda { Post.new(1).save('body'=>'My Post') }.should.raise Redis::Objects::V::AttributeRequired
  end

  it "should call custom validation" do
    lambda { Post.new(1).save('title'=>'Post', 'tag'=>'ho') }.should.raise
    Post.new(1).save('title'=>'Post', 'tag'=>'hello')
  end

  it "should support marshalling of types" do
    Post.new(1).save('title'=>'My Post', 'created_at'=>Time.now)
    Post.new(1).attrs['created_at'].class.should == Time
  end

  it "should support custom marshalling" do
    Post.new(1).save('title'=>"My Post", 'password'=>'secret')
    Post.redis.hget('post:1:attrs','password').should == "secret_encrypted"
    Post.new(1).attrs['password'].should == 'secret'

  end

  it "should have a get method" do
    Post.get(1).should.be.nil
    Post.new(1).save('title'=>'My Post')
    Post.get(1).is_a?(Post).should.be.true
  end

  it "should have a create method" do
    Post.new(1).exists?.should.be.false
    p = Post.create(1, {'title'=>'My Post'})
    Post.new(1).exists?.should.be.true
  end

  it "should have to_json" do
    Post.new(1).save('title'=>'My Post').to_json.should == \
      {'id' => 1, 'title' => 'My Post'}.to_json
  end

  it "should hava a destroy method" do
    Post.new(1).save('title'=>"My Post", 'password'=>'secret')
    Post.new(1).destroy
    $redis.exists('post:1:attrs').should == false
  end

  describe "Keys" do
    it "should support incremental keys" do
      Link.new.save('url'=>'http://google.ca')
      $redis.get("link::ids").to_i.should == 1
      Link.new(1).attrs['url'].should == 'http://google.ca'
    end

    it "should support incremental keys" do
      Link.new.save('url'=>'http://google.ca')
      $redis.get("link::ids").to_i.should == 1
      Link.new(1).attrs['url'].should == 'http://google.ca'
      Link.new.save('url'=>'http://yahoo.com')
      $redis.get("link::ids").to_i.should == 2
    end

    it "should not increment counter if validation fails" do
      Link.new.save('url'=>'http://google.ca')
      lambda { Link.new.save({}) }.should.raise Redis::Objects::V::AttributeRequired
      $redis.get("link::ids").to_i.should == 1
    end

    it "should support random keys" do
      Account.new.save('name' => 'test')
      Account.all.first.id.should =~ /^\w{5}$/
    end

    it "should retry if random key is taken" do
      Account.key_length = 1
      # prefill a lot of keys, so only a few remain
      ('a'..'z').each { |c| $redis.set("account:#{c}:attrs", "taken") }
      Account.new.save('name' => 'test')
      Account.all.first.id.should =~ /^\d{1}$/
    end

  end

  #
  # Indexes
  #
  it "should have an index" do
    Post.keys.should == []
    Post.create(1, {'title'=>'My Post'})
    Post.keys.should == ["1"]
    Post.new(2).save({'title'=>'Your Post'})
    Post.keys.should == ["2", "1"]
  end

  it "should count the number of objects" do
    Post.count.should == 0
    Post.create(1, {'title'=>'My Post'})
    Post.count.should == 1
    Post.create(2, {'title'=>'Your Post'})
    Post.count.should == 2
  end

  it "all should return instances of the model" do
    Post.create(1, {'title'=>'My Post'})
    Post.create(2, {'title'=>'Your Post'})
    posts = Post.all
    posts.first.attrs['title'].should == "Your Post"
    posts.last.attrs['title'].should == "My Post"
  end

  it "it should query based on indexes given" do
    (1..6).each { |id| Post.create(id, {'title'=>"#{id} post"}) }
    Post.count.should == 6
    Post.all(0,5).last.attrs['title'].should == "1 post"
    Post.all(0,2).last.attrs['title'].should == "4 post"
    Post.all(2,2).last.attrs['title'].should == "2 post"
    Post.all(2,5).size.should == 4
    Post.all(2,5).last.attrs['title'].should == "1 post"
  end

  it "delete should remove the id from the index" do
    Post.create(1, {'title'=>'My Post'})
    Post.new(1).destroy
    Post.keys.should == []
  end

  it "should return json when converting query" do
    Post.create(1, {'title'=>'My Post'})
    Post.all.to_json.should == [{'id'=>'1', 'title'=>'My Post'}].to_json
  end
end
